class WalletModel {
  final String id;
  final String name;
  final String address;
  final String? mnemonic;
  final DateTime createdAt;
  String? balance;
  bool isLoading;

  WalletModel({
    required this.id,
    required this.name,
    required this.address,
    this.mnemonic,
    required this.createdAt,
    this.balance,
    this.isLoading = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'mnemonic': mnemonic,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    mnemonic: json['mnemonic'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String get shortAddress {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  WalletModel copyWith({
    String? name,
    String? balance,
    bool? isLoading,
  }) => WalletModel(
    id: id,
    name: name ?? this.name,
    address: address,
    mnemonic: mnemonic,
    createdAt: createdAt,
    balance: balance ?? this.balance,
    isLoading: isLoading ?? this.isLoading,
  );
}
