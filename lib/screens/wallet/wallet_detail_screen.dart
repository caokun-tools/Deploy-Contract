import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/address_chip.dart'; // ignore: unused_import

class WalletDetailScreen extends StatefulWidget {
  final WalletModel wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  String? _privateKey;
  bool _showPrivateKey = false;
  bool _isLoadingKey = false;
  late WalletModel _wallet;

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final np = context.read<NetworkProvider>();
    final balance = await np.getBalance(_wallet.address);
    if (mounted) setState(() => _wallet = _wallet.copyWith(balance: balance));
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NetworkProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHero(np),
              ),
              actions: [
                PopupMenuButton<String>(
                  color: AppColors.card,
                  onSelected: (v) {
                    if (v == 'rename') _showRenameDialog();
                    if (v == 'delete') _showDeleteDialog();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('重命名', style: TextStyle(color: AppColors.textPrimary)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('删除钱包', style: TextStyle(color: AppColors.error)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAddressSection(),
                    const SizedBox(height: 16),
                    _buildQRSection(),
                    const SizedBox(height: 16),
                    _buildPrivateKeySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(NetworkProvider np) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.8), AppColors.secondary.withOpacity(0.6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _wallet.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _wallet.balance != null
                    ? '${_wallet.balance} ${np.current.symbol}'
                    : '余额加载中...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _refreshBalance,
                child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '钱包地址',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _wallet.address,
                  style: AppTheme.monoStyle.copyWith(fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _wallet.address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('地址已复制'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            '收款二维码',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: _wallet.address,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _wallet.shortAddress,
            style: AppTheme.monoStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateKeySection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.error.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security_rounded, color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text(
                '私钥导出',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '私钥掌控全部资产，请勿在任何人面前展示或截图',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_showPrivateKey && _privateKey != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0x$_privateKey',
                    style: AppTheme.monoStyle.copyWith(fontSize: 11, color: AppColors.error),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '0x$_privateKey'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('私钥已复制'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('复制', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _showPrivateKey = false;
                          _privateKey = null;
                        }),
                        icon: const Icon(Icons.visibility_off_rounded, size: 14),
                        label: const Text('隐藏', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else
            GradientButton(
              label: '显示私钥',
              gradient: LinearGradient(
                colors: [AppColors.error.withOpacity(0.8), AppColors.error],
              ),
              icon: const Icon(Icons.key_rounded, color: Colors.white, size: 18),
              isLoading: _isLoadingKey,
              onPressed: _loadAndShowPrivateKey,
              width: double.infinity,
              height: 44,
            ),
        ],
      ),
    );
  }

  Future<void> _loadAndShowPrivateKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('安全警告', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text(
          '确认在安全环境下查看私钥？\n\n请确保：\n• 周围无其他人\n• 没有屏幕录制\n• 不进行截图',
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('我已了解风险', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoadingKey = true);
    if (!mounted) return;
    final wp = context.read<WalletProvider>();
    final pk = await wp.getPrivateKey(_wallet.id);
    if (!mounted) return;
    setState(() {
      _privateKey = pk;
      _showPrivateKey = pk != null;
      _isLoadingKey = false;
    });
  }

  void _showRenameDialog() async {
    final ctrl = TextEditingController(text: _wallet.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('重命名钱包', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: '新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await context.read<WalletProvider>().updateWalletName(_wallet.id, result);
      setState(() => _wallet = _wallet.copyWith(name: result));
    }
  }

  void _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除钱包', style: TextStyle(color: AppColors.error)),
        content: Text(
          '确定要删除"${_wallet.name}"吗？\n此操作不可撤销，请确保已备份私钥。',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<WalletProvider>().deleteWallet(_wallet.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
