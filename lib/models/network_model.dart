import 'package:flutter/material.dart';

enum NetworkType { ethereum, bsc }
enum NetworkEnvironment { mainnet, testnet }

class NetworkModel {
  final String id;
  final String name;
  final String rpcUrl;
  final int chainId;
  final String symbol;
  final String explorerUrl;
  final NetworkType type;
  final NetworkEnvironment environment;

  const NetworkModel({
    required this.id,
    required this.name,
    required this.rpcUrl,
    required this.chainId,
    required this.symbol,
    required this.explorerUrl,
    required this.type,
    required this.environment,
  });

  Color get primaryColor => switch (type) {
    NetworkType.ethereum => const Color(0xFF627EEA),
    NetworkType.bsc => const Color(0xFFF3BA2F),
  };

  Color get secondaryColor => switch (type) {
    NetworkType.ethereum => const Color(0xFF8FA3F5),
    NetworkType.bsc => const Color(0xFFE8A000),
  };

  String get explorerTxUrl => '$explorerUrl/tx/';
  String get explorerAddressUrl => '$explorerUrl/address/';

  bool get isTestnet => environment == NetworkEnvironment.testnet;

  static const List<NetworkModel> defaults = [
    NetworkModel(
      id: 'eth-mainnet',
      name: 'Ethereum 主网',
      rpcUrl: 'https://ethereum-rpc.publicnode.com',
      chainId: 1,
      symbol: 'ETH',
      explorerUrl: 'https://etherscan.io',
      type: NetworkType.ethereum,
      environment: NetworkEnvironment.mainnet,
    ),
    NetworkModel(
      id: 'eth-sepolia',
      name: 'Ethereum Sepolia',
      rpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
      chainId: 11155111,
      symbol: 'ETH',
      explorerUrl: 'https://sepolia.etherscan.io',
      type: NetworkType.ethereum,
      environment: NetworkEnvironment.testnet,
    ),
    NetworkModel(
      id: 'bsc-mainnet',
      name: 'BNB Smart Chain 主网',
      rpcUrl: 'https://bsc-rpc.publicnode.com',
      chainId: 56,
      symbol: 'BNB',
      explorerUrl: 'https://bscscan.com',
      type: NetworkType.bsc,
      environment: NetworkEnvironment.mainnet,
    ),
    NetworkModel(
      id: 'bsc-testnet',
      name: 'BSC 测试网',
      rpcUrl: 'https://bsc-testnet-rpc.publicnode.com',
      chainId: 97,
      symbol: 'tBNB',
      explorerUrl: 'https://testnet.bscscan.com',
      type: NetworkType.bsc,
      environment: NetworkEnvironment.testnet,
    ),
  ];
}
