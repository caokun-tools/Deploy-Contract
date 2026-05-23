import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';
import '../services/web3_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService;
  final Web3Service _web3Service;

  List<WalletModel> _wallets = [];
  WalletModel? _activeWallet;
  bool _isLoading = false;
  String? _error;

  WalletProvider(this._walletService, this._web3Service) {
    loadWallets();
  }

  List<WalletModel> get wallets => _wallets;
  WalletModel? get activeWallet => _activeWallet;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasWallets => _wallets.isNotEmpty;

  Future<void> loadWallets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _wallets = await _walletService.loadWallets();
      if (_activeWallet == null && _wallets.isNotEmpty) {
        _activeWallet = _wallets.first;
      }
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<(WalletModel, String)> createWallet(String name) async {
    _error = null;
    final result = await _walletService.generateWallet(name);
    final wallet = result.$1;
    _wallets.add(wallet);
    _activeWallet ??= wallet;
    notifyListeners();
    return result;
  }

  Future<WalletModel> importFromPrivateKey(String name, String privateKey) async {
    _error = null;
    final wallet = await _walletService.importFromPrivateKey(name, privateKey);
    _wallets.add(wallet);
    _activeWallet ??= wallet;
    notifyListeners();
    return wallet;
  }

  Future<WalletModel> importFromMnemonic(String name, String mnemonic) async {
    _error = null;
    final wallet = await _walletService.importFromMnemonic(name, mnemonic);
    _wallets.add(wallet);
    _activeWallet ??= wallet;
    notifyListeners();
    return wallet;
  }

  Future<void> deleteWallet(String walletId) async {
    await _walletService.deleteWallet(walletId);
    _wallets.removeWhere((w) => w.id == walletId);
    if (_activeWallet?.id == walletId) {
      _activeWallet = _wallets.isNotEmpty ? _wallets.first : null;
    }
    notifyListeners();
  }

  void setActiveWallet(WalletModel wallet) {
    _activeWallet = wallet;
    notifyListeners();
  }

  Future<String?> getPrivateKey(String walletId) async {
    return _walletService.getPrivateKey(walletId);
  }

  Future<EthPrivateKey?> getPrivateKeyCredentials(String walletId) async {
    return _walletService.getCredentials(walletId);
  }

  Future<void> refreshBalance(WalletModel wallet) async {
    final idx = _wallets.indexWhere((w) => w.id == wallet.id);
    if (idx < 0) return;
    _wallets[idx] = wallet.copyWith(isLoading: true);
    notifyListeners();
    try {
      final balance = await _web3Service.getBalance(wallet.address);
      _wallets[idx] = wallet.copyWith(balance: balance, isLoading: false);
      if (_activeWallet?.id == wallet.id) {
        _activeWallet = _wallets[idx];
      }
    } catch (_) {
      _wallets[idx] = wallet.copyWith(isLoading: false);
    }
    notifyListeners();
  }

  Future<void> updateWalletName(String walletId, String newName) async {
    await _walletService.updateWalletName(walletId, newName);
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx >= 0) {
      final updated = _wallets[idx].copyWith(name: newName);
      _wallets[idx] = updated;
      if (_activeWallet?.id == walletId) _activeWallet = updated;
      notifyListeners();
    }
  }
}
