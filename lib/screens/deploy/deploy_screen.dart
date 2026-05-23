import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web3dart/web3dart.dart';
import '../../theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/network_provider.dart';
import '../../models/wallet_model.dart';
import '../../models/contract_model.dart';
import '../../models/network_model.dart';
import '../../services/web3_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/address_chip.dart';
import '../../widgets/network_selector.dart';

enum _DeployState { idle, success, failed }

class DeployScreen extends StatefulWidget {
  const DeployScreen({super.key});

  @override
  State<DeployScreen> createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen> {
  WalletModel? _selectedWallet;
  ContractModel? _selectedContract;
  BigInt _gasLimit = BigInt.from(3000000);
  double _gasPriceGwei = 5.0;
  bool _isEstimating = false;
  bool _isDeploying = false;
  GasEstimate? _gasEstimate;
  _DeployState _deployState = _DeployState.idle;
  String? _txHash;
  String? _contractAddress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wp = context.read<WalletProvider>();
      final cp = context.read<ContractProvider>();
      setState(() {
        _selectedWallet = wp.activeWallet;
        _selectedContract = cp.selectedContract ??
            (cp.contracts.isNotEmpty ? cp.contracts.first : null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: switch (_deployState) {
                _DeployState.success => _buildSuccessView(),
                _DeployState.failed => _buildFailureView(),
                _ => _buildDeployForm(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '一键部署',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  '将合约部署到以太坊或 BSC',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const NetworkSelector(compact: true),
        ],
      ),
    );
  }

  Widget _buildDeployForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWalletSelector(),
          const SizedBox(height: 12),
          _buildContractSelector(),
          const SizedBox(height: 12),
          _buildGasSettings(),
          const SizedBox(height: 12),
          _buildDeploySummary(),
          const SizedBox(height: 16),
          _buildDeployButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWalletSelector() {
    return Consumer<WalletProvider>(
      builder: (ctx, wp, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text('签名钱包',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (wp.wallets.isEmpty)
              const Text('没有可用钱包，请先创建或导入钱包',
                  style: TextStyle(color: AppColors.error, fontSize: 13))
            else
              DropdownButton<WalletModel>(
                isExpanded: true,
                value: _selectedWallet,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                underline: Container(height: 1, color: AppColors.cardBorder),
                icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
                items: wp.wallets
                    .map((w) => DropdownMenuItem(
                          value: w,
                          child: Row(
                            children: [
                              _ColorDot(address: w.address),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(w.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                    Text(w.shortAddress,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (w) => setState(() {
                  _selectedWallet = w;
                  _gasEstimate = null;
                }),
              ),
            if (_selectedWallet != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '余额: ${_selectedWallet!.balance ?? '加载中...'} ${context.watch<NetworkProvider>().current.symbol}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContractSelector() {
    return Consumer<ContractProvider>(
      builder: (ctx, cp, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.code_rounded, color: AppColors.secondary, size: 18),
                SizedBox(width: 8),
                Text('选择合约',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (cp.contracts.isEmpty)
              const Text('没有合约，请先在合约页面导入',
                  style: TextStyle(color: AppColors.error, fontSize: 13))
            else
              DropdownButton<ContractModel>(
                isExpanded: true,
                value: _selectedContract,
                dropdownColor: AppColors.card,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                underline: Container(height: 1, color: AppColors.cardBorder),
                icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
                items: cp.contracts
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              const Icon(Icons.code_rounded,
                                  size: 16, color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                    Text(
                                        '${c.cleanBytecode.length ~/ 2} 字节',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (c.isDeployed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '已部署',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (c) => setState(() {
                  _selectedContract = c;
                  _gasEstimate = null;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGasSettings() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Row(
                children: [
                  Icon(Icons.local_gas_station_rounded,
                      color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Text('Gas 设置',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _estimateGas,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: _isEstimating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.warning),
                        )
                      : const Text(
                          '估算 Gas',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_gasEstimate != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_rounded,
                      color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gas 价格: ${_gasEstimate!.gasPriceGwei}',
                          style: const TextStyle(
                              color: AppColors.success, fontSize: 12),
                        ),
                        Text(
                          '预计费用: ${_gasEstimate!.totalCostEth}',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _gasLimit = _gasEstimate!.gasLimit;
                      _gasPriceGwei = double.parse(
                        _gasEstimate!.gasPrice
                            .getValueInUnit(EtherUnit.gwei)
                            .toStringAsFixed(2),
                      );
                    }),
                    child: const Text('应用',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gas Limit',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: _gasLimit.toString(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final parsed = BigInt.tryParse(v);
                        if (parsed != null) setState(() => _gasLimit = parsed);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gas Price (Gwei)',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: _gasPriceGwei.toStringAsFixed(1),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null)
                          setState(() => _gasPriceGwei = parsed);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeploySummary() {
    final np = context.watch<NetworkProvider>();
    if (_selectedWallet == null || _selectedContract == null)
      return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withOpacity(0.1),
          AppColors.secondary.withOpacity(0.05),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '部署摘要',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.link_rounded,
            label: '目标网络',
            value: '${np.current.name} (Chain ID: ${np.current.chainId})',
            valueColor: np.current.primaryColor,
          ),
          _SummaryRow(
            icon: Icons.account_balance_wallet_rounded,
            label: '部署账户',
            value: _selectedWallet!.shortAddress,
          ),
          _SummaryRow(
            icon: Icons.code_rounded,
            label: '合约',
            value:
                '${_selectedContract!.name} (${_selectedContract!.cleanBytecode.length ~/ 2} 字节)',
          ),
          _SummaryRow(
            icon: Icons.local_gas_station_rounded,
            label: 'Gas Limit',
            value: _gasLimit.toString(),
          ),
          const SizedBox(height: 8),
          if (np.current.isTestnet)
            _InfoBanner(
              icon: Icons.info_outline_rounded,
              text: '测试网，不消耗真实资产',
              color: AppColors.info,
            )
          else
            _InfoBanner(
              icon: Icons.warning_rounded,
              text: '主网部署将消耗真实资产，请确认钱包余额充足',
              color: AppColors.error,
            ),
        ],
      ),
    );
  }

  Widget _buildDeployButton() {
    final canDeploy =
        _selectedWallet != null && _selectedContract != null && !_isDeploying;
    final np = context.watch<NetworkProvider>();

    return GradientButton(
      label: _isDeploying ? '部署中...' : '立即部署',
      gradient: np.current.isTestnet
          ? AppColors.primaryGradient
          : const LinearGradient(
              colors: [Color(0xFFFF5252), Color(0xFFD32F2F)]),
      icon: _isDeploying
          ? null
          : const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
      isLoading: _isDeploying,
      onPressed: canDeploy ? _deploy : null,
      width: double.infinity,
      height: 56,
    );
  }

  Widget _buildSuccessView() {
    final np = context.watch<NetworkProvider>();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '部署成功！',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '智能合约已成功部署到区块链',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (_contractAddress != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('合约地址',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    FullAddressBox(address: _contractAddress!),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_txHash != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('交易哈希',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    FullAddressBox(address: _txHash!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openExplorer(np),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('在区块链浏览器中查看',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: '继续部署其他合约',
              onPressed: () => setState(() {
                _deployState = _DeployState.idle;
                _txHash = null;
                _contractAddress = null;
                _errorMessage = null;
              }),
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFD32F2F)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.error.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6)),
                ],
              ),
              child:
                  const Icon(Icons.close_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              '部署失败',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.error.withOpacity(0.3),
              child: Text(
                _errorMessage ?? '未知错误',
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: '重试',
              gradient: AppColors.primaryGradient,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => setState(() {
                _deployState = _DeployState.idle;
                _errorMessage = null;
              }),
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _estimateGas() async {
    if (_selectedWallet == null || _selectedContract == null) return;
    setState(() => _isEstimating = true);
    try {
      final np = context.read<NetworkProvider>();
      final from = EthereumAddress.fromHex(_selectedWallet!.address);
      final estimate = await np.web3Service.estimateDeployGas(
        from: from,
        bytecodeHex: _selectedContract!.cleanBytecode,
        constructorArgs: [],
      );
      setState(() {
        _gasEstimate = estimate;
        _isEstimating = false;
      });
    } catch (e) {
      setState(() => _isEstimating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gas 估算失败: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deploy() async {
    if (_selectedWallet == null || _selectedContract == null) return;
    final np = context.read<NetworkProvider>();
    if (!np.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('网络未连接，请检查网络设置'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final confirmed = await _showDeployConfirm(np.current);
    if (confirmed != true) return;

    setState(() => _isDeploying = true);

    try {
      if (!mounted) return;
      final wp = context.read<WalletProvider>();
      final credentials = await wp.getPrivateKeyCredentials(_selectedWallet!.id);
      if (credentials == null) throw Exception('无法获取钱包私钥');

      final gasPriceWei = BigInt.from((_gasPriceGwei * 1e9).round());
      final gasPrice = EtherAmount.fromBigInt(EtherUnit.wei, gasPriceWei);

      final result = await np.web3Service.deployContract(
        credentials: credentials,
        bytecodeHex: _selectedContract!.cleanBytecode,
        constructorArgs: [],
        gasLimit: _gasLimit,
        gasPrice: gasPrice,
      );

      if (!mounted) return;
      if (result.success) {
        await context.read<ContractProvider>().updateDeployInfo(
          contractId: _selectedContract!.id,
          txHash: result.txHash,
          contractAddress: result.contractAddress,
          chainId: np.current.chainId,
        );
        if (!mounted) return;
        setState(() {
          _txHash = result.txHash;
          _contractAddress = result.contractAddress;
          _deployState = _DeployState.success;
          _isDeploying = false;
        });
      } else {
        setState(() {
          _errorMessage = result.error;
          _deployState = _DeployState.failed;
          _isDeploying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _deployState = _DeployState.failed;
        _isDeploying = false;
      });
    }
  }

  Future<bool?> _showDeployConfirm(NetworkModel network) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              color: network.isTestnet ? AppColors.primary : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              '确认部署',
              style: TextStyle(
                color: network.isTestnet
                    ? AppColors.textPrimary
                    : AppColors.error,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将 "${_selectedContract!.name}" 部署到',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              network.name,
              style: TextStyle(
                color: network.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (!network.isTestnet) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '主网操作不可撤销，将消耗真实资产！',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '确认部署',
              style: TextStyle(
                color: network.isTestnet ? AppColors.primary : AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExplorer(NetworkProvider np) {
    if (_txHash == null) return;
    final explorerUrl = '${np.current.explorerTxUrl}$_txHash';
    Clipboard.setData(ClipboardData(text: explorerUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('区块链浏览器链接已复制到剪贴板'),
          duration: Duration(seconds: 2)),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String address;

  const _ColorDot({required this.address});

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      Color(0xFFFF6B9D),
      AppColors.warning,
      AppColors.success,
    ];
    final color = colors[address.codeUnitAt(2) % colors.length];
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          address.substring(2, 4).toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 11))),
        ],
      ),
    );
  }
}
