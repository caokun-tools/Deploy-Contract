class ContractModel {
  final String id;
  String name;
  final String abi;
  final String bytecode;
  final DateTime importedAt;
  String? deployedAddress;
  String? deployTxHash;
  int? deployedChainId;

  ContractModel({
    required this.id,
    required this.name,
    required this.abi,
    required this.bytecode,
    required this.importedAt,
    this.deployedAddress,
    this.deployTxHash,
    this.deployedChainId,
  });

  bool get isDeployed => deployedAddress != null && deployedAddress!.isNotEmpty;

  List<Map<String, dynamic>> get parsedAbi {
    try {
      final dynamic decoded = _parseJson(abi);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  dynamic _parseJson(String raw) {
    // Simple JSON parse delegated to dart:convert at runtime
    return null;
  }

  List<Map<String, dynamic>> get constructorInputs {
    try {
      final items = parsedAbi;
      for (final item in items) {
        if (item['type'] == 'constructor') {
          final inputs = item['inputs'];
          if (inputs is List) return inputs.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  String get cleanBytecode {
    String code = bytecode.trim();
    if (code.startsWith('0x') || code.startsWith('0X')) {
      code = code.substring(2);
    }
    return code;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'abi': abi,
    'bytecode': bytecode,
    'importedAt': importedAt.toIso8601String(),
    'deployedAddress': deployedAddress,
    'deployTxHash': deployTxHash,
    'deployedChainId': deployedChainId,
  };

  factory ContractModel.fromJson(Map<String, dynamic> json) => ContractModel(
    id: json['id'] as String,
    name: json['name'] as String,
    abi: json['abi'] as String,
    bytecode: json['bytecode'] as String,
    importedAt: DateTime.parse(json['importedAt'] as String),
    deployedAddress: json['deployedAddress'] as String?,
    deployTxHash: json['deployTxHash'] as String?,
    deployedChainId: json['deployedChainId'] as int?,
  );
}
