import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import '../models/wallet_model.dart';

class WalletService {
  static const _walletsKey = 'wallets_list';
  static const _pkPrefix = 'pk_';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<(WalletModel, String)> generateWallet(String name) async {
    final mnemonic = bip39.generateMnemonic();
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/0/0");
    final privateKeyBytes = child.privateKey!;
    final credentials = EthPrivateKey(privateKeyBytes);
    final address = credentials.address.hexEip55;
    final privateKeyHex = HEX.encode(privateKeyBytes);

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

  Future<WalletModel> importFromMnemonic(String name, String mnemonic, {int index = 0}) async {
    final trimmed = mnemonic.trim().toLowerCase();
    if (!bip39.validateMnemonic(trimmed)) throw Exception('助记词格式错误');

    final seed = bip39.mnemonicToSeed(trimmed);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/$index/0");
    final privateKeyBytes = child.privateKey!;
    final credentials = EthPrivateKey(privateKeyBytes);
    final address = credentials.address.hexEip55;
    final privateKeyHex = HEX.encode(privateKeyBytes);

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

  Future<String?> getPrivateKey(String walletId) async {
    return await _storage.read(key: '$_pkPrefix$walletId');
  }

  Future<EthPrivateKey?> getCredentials(String walletId) async {
    final pk = await getPrivateKey(walletId);
    if (pk == null) return null;
    return EthPrivateKey.fromHex(pk);
  }

  Future<List<WalletModel>> loadWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    return jsonList
        .map((s) => WalletModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteWallet(String walletId) async {
    await _storage.delete(key: '$_pkPrefix$walletId');
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

  Future<void> _saveWallet(WalletModel wallet) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    jsonList.add(jsonEncode(wallet.toJson()));
    await prefs.setStringList(_walletsKey, jsonList);
  }

  Future<void> _savePrivateKey(String walletId, String privateKey) async {
    await _storage.write(key: '$_pkPrefix$walletId', value: privateKey);
  }

  String _generateId() {
    final rng = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return HEX.encode(bytes);
  }
}
