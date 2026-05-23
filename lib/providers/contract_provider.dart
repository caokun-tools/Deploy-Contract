import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hex/hex.dart';
import '../models/contract_model.dart';

class ContractProvider extends ChangeNotifier {
  static const _contractsKey = 'contracts_list';

  List<ContractModel> _contracts = [];
  ContractModel? _selectedContract;
  bool _isLoading = false;
  String? _error;

  List<ContractModel> get contracts => _contracts;
  ContractModel? get selectedContract => _selectedContract;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ContractProvider() {
    loadContracts();
  }

  Future<void> loadContracts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_contractsKey) ?? [];
      _contracts = jsonList
          .map((s) => ContractModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<ContractModel> addContract({
    required String name,
    required String abi,
    required String bytecode,
  }) async {
    _validateAbi(abi);
    _validateBytecode(bytecode);

    final contract = ContractModel(
      id: _generateId(),
      name: name,
      abi: abi,
      bytecode: bytecode,
      importedAt: DateTime.now(),
    );
    _contracts.add(contract);
    await _saveContracts();
    notifyListeners();
    return contract;
  }

  Future<void> updateDeployInfo({
    required String contractId,
    required String txHash,
    required String? contractAddress,
    required int chainId,
  }) async {
    final idx = _contracts.indexWhere((c) => c.id == contractId);
    if (idx < 0) return;
    _contracts[idx].deployTxHash = txHash;
    _contracts[idx].deployedAddress = contractAddress;
    _contracts[idx].deployedChainId = chainId;
    if (_selectedContract?.id == contractId) {
      _selectedContract = _contracts[idx];
    }
    await _saveContracts();
    notifyListeners();
  }

  Future<void> deleteContract(String contractId) async {
    _contracts.removeWhere((c) => c.id == contractId);
    if (_selectedContract?.id == contractId) _selectedContract = null;
    await _saveContracts();
    notifyListeners();
  }

  void selectContract(ContractModel? contract) {
    _selectedContract = contract;
    notifyListeners();
  }

  Future<void> _saveContracts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _contracts.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_contractsKey, jsonList);
  }

  void _validateAbi(String abi) {
    try {
      final decoded = jsonDecode(abi);
      if (decoded is! List) throw Exception('ABI 必须是 JSON 数组格式');
    } catch (e) {
      if (e.toString().contains('ABI')) rethrow;
      throw Exception('ABI JSON 格式无效: $e');
    }
  }

  void _validateBytecode(String bytecode) {
    String code = bytecode.trim();
    if (code.startsWith('0x') || code.startsWith('0X')) code = code.substring(2);
    if (code.isEmpty) throw Exception('字节码不能为空');
    if (code.length % 2 != 0) throw Exception('字节码长度必须为偶数');
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    if (!hexRegex.hasMatch(code)) throw Exception('字节码必须为十六进制格式');
  }

  String _generateId() {
    final rng = Random.secure();
    final bytes = Uint8List(8);
    for (int i = 0; i < 8; i++) bytes[i] = rng.nextInt(256);
    return HEX.encode(bytes);
  }
}
