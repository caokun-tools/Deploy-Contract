import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/contract_model.dart';
import '../../providers/contract_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/address_chip.dart';

class ContractDetailScreen extends StatelessWidget {
  final ContractModel contract;

  const ContractDetailScreen({super.key, required this.contract});

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
              expandedHeight: 160,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.7),
                        AppColors.primary.withOpacity(0.5),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        contract.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (contract.isDeployed)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                              SizedBox(width: 4),
                              Text('已部署', style: TextStyle(color: AppColors.success, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                  onPressed: () => _delete(context),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contract.isDeployed) ...[
                      _buildDeployInfo(context, contract, np),
                      const SizedBox(height: 16),
                    ],
                    _buildAbiSection(context),
                    const SizedBox(height: 16),
                    _buildBytecodeSection(context),
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

  Widget _buildDeployInfo(BuildContext context, ContractModel c, NetworkProvider np) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.success.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text(
                '部署信息',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (c.deployedAddress != null) ...[
            const Text('合约地址', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            FullAddressBox(address: c.deployedAddress!),
            const SizedBox(height: 10),
          ],
          if (c.deployTxHash != null) ...[
            const Text('交易哈希', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            FullAddressBox(address: c.deployTxHash!),
          ],
          if (c.deployedChainId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('网络', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Chain ID: ${c.deployedChainId}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbiSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Row(
                children: [
                  Icon(Icons.data_object_rounded, color: AppColors.secondary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'ABI',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: contract.abi));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ABI 已复制'), duration: Duration(seconds: 1)),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('复制', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Text(
                contract.abi,
                style: AppTheme.monoStyle.copyWith(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBytecodeSection(BuildContext context) {
    final bytecode = contract.cleanBytecode;
    final size = bytecode.length ~/ 2;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Row(
                children: [
                  Icon(Icons.memory_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '字节码',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$size 字节', style: const TextStyle(color: AppColors.primary, fontSize: 10)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '0x${contract.cleanBytecode}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('字节码已复制'), duration: Duration(seconds: 1)),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('复制', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Text(
                '0x${bytecode.substring(0, bytecode.length > 200 ? 200 : bytecode.length)}...',
                style: AppTheme.monoStyle.copyWith(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('删除合约', style: TextStyle(color: AppColors.error)),
        content: Text(
          '确定删除"${contract.name}"吗？',
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
    if (confirmed == true && context.mounted) {
      await context.read<ContractProvider>().deleteContract(contract.id);
      Navigator.pop(context);
    }
  }
}
