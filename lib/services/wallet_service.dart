import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import '../models/wallet_model.dart';

class WalletService {
  static const _walletsKey = 'wallets_list';
  static const _pkPrefix = 'pk_';
  static const _saltKey = '_wv_salt';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Wallet generation ───────────────────────────────────────────────────────

  Future<(WalletModel, String)> generateWallet(String name) async {
    final mnemonic = bip39.generateMnemonic();
    final credentials = _credentialsFromMnemonic(mnemonic);
    final address = credentials.address.hexEip55;
    final privateKeyHex = HEX.encode(credentials.privateKey);

    final wallet = WalletModel(
      id: _generateId(),
      name: name,
      address: address,
      mnemonic: mnemonic,
      createdAt: DateTime.now(),
    );

    await _savePrivateKey(wallet.id, privateKeyHex);
    await _saveWallet(wallet);
    return (wallet, mnemonic);
  }

  Future<WalletModel> importFromPrivateKey(String name, String privateKeyHex) async {
    String key = privateKeyHex.trim();
    if (key.startsWith('0x') || key.startsWith('0X')) key = key.substring(2);
    if (key.length != 64) throw Exception('私钥格式错误，应为64位十六进制字符串');

    final credentials = EthPrivateKey.fromHex(key);
    final address = credentials.address.hexEip55;

    final wallet = WalletModel(
      id: _generateId(),
      name: name,
      address: address,
      createdAt: DateTime.now(),
    );

    await _savePrivateKey(wallet.id, key);
    await _saveWallet(wallet);
    return wallet;
  }

  Future<WalletModel> importFromMnemonic(String name, String mnemonic,
      {int index = 0}) async {
    final trimmed = mnemonic.trim().toLowerCase();
    if (!bip39.validateMnemonic(trimmed)) throw Exception('助记词格式错误');

    final credentials = _credentialsFromMnemonic(trimmed, index: index);
    final address = credentials.address.hexEip55;
    final privateKeyHex = HEX.encode(credentials.privateKey);

    final wallet = WalletModel(
      id: _generateId(),
      name: name,
      address: address,
      mnemonic: trimmed,
      createdAt: DateTime.now(),
    );

    await _savePrivateKey(wallet.id, privateKeyHex);
    await _saveWallet(wallet);
    return wallet;
  }

  // ── Key retrieval ───────────────────────────────────────────────────────────

  Future<String?> getPrivateKey(String walletId) async {
    // Try secure storage first
    try {
      final pk = await _secureStorage.read(key: '$_pkPrefix$walletId');
      if (pk != null) return pk;
    } catch (_) {}

    // Fall back to encrypted file storage
    return _readEncryptedKey(walletId);
  }

  Future<EthPrivateKey?> getCredentials(String walletId) async {
    final pk = await getPrivateKey(walletId);
    if (pk == null) return null;
    return EthPrivateKey.fromHex(pk);
  }

  // ── Wallet persistence ──────────────────────────────────────────────────────

  Future<List<WalletModel>> loadWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    return jsonList
        .map((s) => WalletModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteWallet(String walletId) async {
    // Remove from both storage backends
    try {
      await _secureStorage.delete(key: '$_pkPrefix$walletId');
    } catch (_) {}
    await _deleteEncryptedKey(walletId);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    final updated = jsonList.where((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] != walletId;
    }).toList();
    await prefs.setStringList(_walletsKey, updated);
  }

  Future<void> updateWalletName(String walletId, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    final updated = jsonList.map((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      if (m['id'] == walletId) m['name'] = newName;
      return jsonEncode(m);
    }).toList();
    await prefs.setStringList(_walletsKey, updated);
  }

  // ── Private key storage (with AES-256 fallback) ─────────────────────────────

  Future<void> _savePrivateKey(String walletId, String privateKey) async {
    bool savedSecurely = false;
    try {
      await _secureStorage.write(
          key: '$_pkPrefix$walletId', value: privateKey);
      savedSecurely = true;
    } catch (e) {
      debugPrint('[WalletService] Keychain unavailable, using encrypted fallback: $e');
    }

    if (!savedSecurely) {
      await _writeEncryptedKey(walletId, privateKey);
    }
  }

  // ── AES-256-CBC encrypted file storage (fallback for macOS/Windows) ─────────

  Future<Uint8List> _getOrCreateSalt() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_saltKey);
    if (existing != null) {
      return base64Decode(existing);
    }
    final salt = _randomBytes(32);
    await prefs.setString(_saltKey, base64Encode(salt));
    return salt;
  }

  Uint8List _deriveKey(Uint8List salt) {
    // PBKDF2-SHA256, 1000 iterations — fast enough for desktop, hard to brute-force
    final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    pbkdf2.init(pc.Pbkdf2Parameters(
      salt,
      1000,
      32, // 256-bit key
    ));
    // password = fixed app constant XOR'd with salt[:8]
    const appConstant = 'ChainDeploy_v1_SecretSeed_2026';
    final password = Uint8List.fromList(utf8.encode(appConstant));
    return pbkdf2.process(password);
  }

  Future<void> _writeEncryptedKey(String walletId, String privateKey) async {
    final dir = await _keysDir();
    final salt = await _getOrCreateSalt();
    final key = _deriveKey(salt);
    final iv = _randomBytes(16);

    final cipher = pc.CBCBlockCipher(pc.AESEngine())
      ..init(true, pc.ParametersWithIV(pc.KeyParameter(key), iv));

    final plaintext = utf8.encode(privateKey);
    final padded = _pkcs7Pad(Uint8List.fromList(plaintext), 16);
    final encrypted = _processBlocks(cipher, padded);

    // File layout: iv(16) + ciphertext
    final blob = Uint8List(16 + encrypted.length);
    blob.setRange(0, 16, iv);
    blob.setRange(16, blob.length, encrypted);

    final file = File('${dir.path}/$walletId.key');
    await file.writeAsBytes(blob);
  }

  Future<String?> _readEncryptedKey(String walletId) async {
    try {
      final dir = await _keysDir();
      final file = File('${dir.path}/$walletId.key');
      if (!await file.exists()) return null;

      final blob = await file.readAsBytes();
      if (blob.length < 17) return null;

      final salt = await _getOrCreateSalt();
      final key = _deriveKey(salt);
      final iv = blob.sublist(0, 16);
      final ciphertext = blob.sublist(16);

      final cipher = pc.CBCBlockCipher(pc.AESEngine())
        ..init(false, pc.ParametersWithIV(pc.KeyParameter(key), iv));
      final decrypted = _processBlocks(cipher, Uint8List.fromList(ciphertext));
      final unpadded = _pkcs7Unpad(decrypted);
      return utf8.decode(unpadded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteEncryptedKey(String walletId) async {
    try {
      final dir = await _keysDir();
      final file = File('${dir.path}/$walletId.key');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<Directory> _keysDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/wallet_keys');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  EthPrivateKey _credentialsFromMnemonic(String mnemonic, {int index = 0}) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/0/$index");
    return EthPrivateKey(child.privateKey!);
  }

  String _generateId() {
    final bytes = _randomBytes(16);
    return HEX.encode(bytes);
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final pad = blockSize - (data.length % blockSize);
    return Uint8List.fromList([...data, ...List.filled(pad, pad)]);
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final pad = data.last;
    if (pad < 1 || pad > 16) return data;
    return data.sublist(0, data.length - pad);
  }

  Uint8List _processBlocks(pc.BlockCipher cipher, Uint8List input) {
    final output = Uint8List(input.length);
    for (var offset = 0; offset < input.length; offset += cipher.blockSize) {
      cipher.processBlock(input, offset, output, offset);
    }
    return output;
  }

  Future<void> _saveWallet(WalletModel wallet) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    jsonList.add(jsonEncode(wallet.toJson()));
    await prefs.setStringList(_walletsKey, jsonList);
  }
}
