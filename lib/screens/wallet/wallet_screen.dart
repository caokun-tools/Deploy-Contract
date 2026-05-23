import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart' as gb;
import '../../widgets/address_chip.dart';
import '../../widgets/network_selector.dart';
import 'create_wallet_screen.dart';
import 'import_wallet_screen.dart';
import 'wallet_detail_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBalances();
    });
  }

  void _refreshBalances() {
    final walletProvider = context.read<WalletProvider>();
    for (final wallet in walletProvider.wallets) {
      walletProvider.refreshBalance(wallet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<WalletProvider>(
                builder: (ctx, wp, _) {
                  if (wp.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (wp.wallets.isEmpty) {
                    return _EmptyWalletView(
                      onCreateTap: () => _showCreateWallet(context),
                      onImportTap: () => _showImportWallet(context),
                    );
                  }
                  return _WalletList(wallets: wp.wallets, walletProvider: wp);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _AddWalletFab(
        onCreateTap: () => _showCreateWallet(context),
        onImportTap: () => _showImportWallet(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的钱包',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'ERC-20 兼容钱包管理',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const NetworkSelector(compact: true),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _refreshBalances,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showCreateWallet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateWalletSheet(),
    );
    if (result == true && mounted) {
      _refreshBalances();
    }
  }

  void _showImportWallet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImportWalletSheet(),
    );
    if (result == true && mounted) {
      _refreshBalances();
    }
  }
}

class _WalletList extends StatelessWidget {
  final List<WalletModel> wallets;
  final WalletProvider walletProvider;

  const _WalletList({required this.wallets, required this.walletProvider});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: wallets.length,
      itemBuilder: (ctx, i) => _WalletCard(
        wallet: wallets[i],
        isActive: walletProvider.activeWallet?.id == wallets[i].id,
        onTap: () {
          walletProvider.setActiveWallet(wallets[i]);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WalletDetailScreen(wallet: wallets[i])),
          );
        },
        onSetActive: () => walletProvider.setActiveWallet(wallets[i]),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSetActive;

  const _WalletCard({
    required this.wallet,
    required this.isActive,
    required this.onTap,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: isActive ? AppColors.primary.withOpacity(0.5) : AppColors.cardBorder,
      onTap: onTap,
      child: Row(
        children: [
          _WalletAvatar(address: wallet.address, isActive: isActive),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        wallet.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                AddressChip(address: wallet.address, showCopy: false),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (wallet.isLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      Text(
                        wallet.balance != null ? '${wallet.balance} ETH' : '-- ETH',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _WalletAvatar extends StatelessWidget {
  final String address;
  final bool isActive;

  const _WalletAvatar({required this.address, required this.isActive});

  Color _avatarColor() {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      const Color(0xFFFF6B9D),
      const Color(0xFFFFD140),
      const Color(0xFF00E676),
    ];
    final idx = address.codeUnitAt(2) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: Center(
        child: Text(
          address.substring(2, 4).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _EmptyWalletView extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onImportTap;

  const _EmptyWalletView({required this.onCreateTap, required this.onImportTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text(
              '还没有钱包',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '创建一个新钱包或导入现有钱包\n开始部署智能合约',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            gb.GradientButton(
              label: '创建新钱包',
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: onCreateTap,
              width: 240,
            ),
            const SizedBox(height: 12),
            gb.OutlineButton(
              label: '导入钱包',
              icon: const Icon(Icons.download_rounded, size: 16),
              onPressed: onImportTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWalletFab extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onImportTap;

  const _AddWalletFab({required this.onCreateTap, required this.onImportTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (ctx, wp, _) {
        if (!wp.hasWallets) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              onPressed: onCreateTap,
              heroTag: 'create_wallet',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建钱包', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              onPressed: onImportTap,
              heroTag: 'import_wallet',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 2,
              child: const Icon(Icons.download_rounded, size: 20),
            ),
          ],
        );
      },
    );
  }
}
