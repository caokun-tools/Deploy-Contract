import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import '../models/network_model.dart';

class DeployResult {
  final String txHash;
  final String? contractAddress;
  final bool success;
  final String? error;

  DeployResult({
    required this.txHash,
    this.contractAddress,
    required this.success,
    this.error,
  });
}

class GasEstimate {
  final BigInt gasLimit;
  final EtherAmount gasPrice;
  final EtherAmount totalCost;

  GasEstimate({
    required this.gasLimit,
    required this.gasPrice,
    required this.totalCost,
  });

  String get gasPriceGwei {
    final gwei = gasPrice.getValueInUnit(EtherUnit.gwei);
    return '${gwei.toStringAsFixed(2)} Gwei';
  }

  String get totalCostEth {
    final eth = totalCost.getValueInUnit(EtherUnit.ether);
    return '${eth.toStringAsFixed(8)} ETH';
  }
}

class Web3Service {
  Web3Client? _client;
  NetworkModel? _currentNetwork;

  void connect(NetworkModel network) {
    _client?.dispose();
    _client = Web3Client(network.rpcUrl, http.Client());
    _currentNetwork = network;
  }

  void dispose() {
    _client?.dispose();
    _client = null;
    _currentNetwork = null;
  }

  Web3Client get client {
    if (_client == null) throw Exception('未连接到网络，请先选择网络');
    return _client!;
  }

  NetworkModel get currentNetwork {
    if (_currentNetwork == null) throw Exception('未选择网络');
    return _currentNetwork!;
  }

  Future<String> getBalance(String address) async {
    try {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await client.getBalance(ethAddress);
      final eth = balance.getValueInUnit(EtherUnit.ether);
      return eth.toStringAsFixed(6);
    } catch (e) {
      return '0.000000';
    }
  }

  Future<EtherAmount> getGasPrice() async {
    return await client.getGasPrice();
  }

  Future<BigInt> getChainId() async {
    final id = await client.getNetworkId();
    return BigInt.from(id);
  }

  Future<bool> testConnection() async {
    try {
      await client.getNetworkId();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<GasEstimate?> estimateDeployGas({
    required EthereumAddress from,
    required String bytecodeHex,
    required List<dynamic> constructorArgs,
  }) async {
    try {
      final data = _buildDeployData(bytecodeHex, constructorArgs);
      final gasPrice = await client.getGasPrice();
      final gasLimit = await client.estimateGas(
        sender: from,
        data: data,
      );
      final bufferedGas = (gasLimit * BigInt.from(12)) ~/ BigInt.from(10);
      final totalCost = EtherAmount.fromBigInt(
        EtherUnit.wei,
        bufferedGas * gasPrice.getInWei,
      );
      return GasEstimate(
        gasLimit: bufferedGas,
        gasPrice: gasPrice,
        totalCost: totalCost,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DeployResult> deployContract({
    required EthPrivateKey credentials,
    required String bytecodeHex,
    required List<dynamic> constructorArgs,
    required BigInt gasLimit,
    required EtherAmount gasPrice,
  }) async {
    try {
      final data = _buildDeployData(bytecodeHex, constructorArgs);
      final nonce = await client.getTransactionCount(
        credentials.address,
        atBlock: const BlockNum.pending(),
      );

      final deployTx = Transaction(
        from: credentials.address,
        data: data,
        gasPrice: gasPrice,
        maxGas: gasLimit.toInt(),
        nonce: nonce,
      );

      final chainId = currentNetwork.chainId;
      final txHash = await client.sendTransaction(
        credentials,
        deployTx,
        chainId: chainId,
      );

      final contractAddress = await _waitForReceipt(txHash);

      return DeployResult(
        txHash: txHash,
        contractAddress: contractAddress,
        success: true,
      );
    } catch (e) {
      return DeployResult(
        txHash: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<String?> _waitForReceipt(String txHash, {int maxAttempts = 60}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final receipt = await client.getTransactionReceipt(txHash);
        if (receipt != null) {
          return receipt.contractAddress?.hexEip55;
        }
      } catch (_) {}
    }
    return null;
  }

  Uint8List _buildDeployData(String bytecodeHex, List<dynamic> constructorArgs) {
    String code = bytecodeHex.trim();
    if (code.startsWith('0x') || code.startsWith('0X')) code = code.substring(2);
    return Uint8List.fromList(HEX.decode(code));
  }
}
