import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_model.dart';
import '../services/web3_service.dart';

class NetworkProvider extends ChangeNotifier {
  final Web3Service _web3Service;

  List<NetworkModel> _networks = NetworkModel.defaults;
  NetworkModel _current = NetworkModel.defaults[1]; // Default: Sepolia testnet
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionError;

  NetworkProvider(this._web3Service) {
    _loadSavedNetwork();
  }

  List<NetworkModel> get networks => _networks;
  NetworkModel get current => _current;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  Web3Service get web3Service => _web3Service;

  Future<void> _loadSavedNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_network');
    if (savedId != null) {
      final found = _networks.where((n) => n.id == savedId).firstOrNull;
      if (found != null) _current = found;
    }
    await connect(_current);
  }

  Future<void> selectNetwork(NetworkModel network) async {
    _current = network;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_network', network.id);
    await connect(network);
  }

  Future<bool> connect(NetworkModel network) async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    _web3Service.connect(network);
    final ok = await _web3Service.testConnection();
    _isConnected = ok;
    _isConnecting = false;
    if (!ok) _connectionError = '无法连接到 ${network.name}';
    notifyListeners();
    return ok;
  }

  Future<String> getBalance(String address) async {
    return _web3Service.getBalance(address);
  }
}
