import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import 'import_contract_screen.dart';
import 'contract_detail_screen.dart';

class ContractScreen extends StatelessWidget {
  const ContractScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<ContractProvider>(
                builder: (ctx, cp, _) {
                  if (cp.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (cp.contracts.isEmpty) {
                    return _EmptyContractView(onImportTap: () => _showImport(ctx));
                  }
                  return _ContractList(contracts: cp.contracts, provider: cp);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Consumer<ContractProvider>(
        builder: (ctx, cp, _) {
          if (cp.contracts.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showImport(ctx),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('导入合约', style: TextStyle(fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '智能合约',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            '管理 ABI 和字节码',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showImport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImportContractSheet(),
    );
  }
}

class _ContractList extends StatelessWidget {
  final List<ContractModel> contracts;
  final ContractProvider provider;

  const _ContractList({required this.contracts, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: contracts.length,
      itemBuilder: (ctx, i) {
        final contract = contracts[i];
        return _ContractCard(
          contract: contract,
          isSelected: provider.selectedContract?.id == contract.id,
          onTap: () {
            provider.selectContract(contract);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContractDetailScreen(contract: contract)),
            );
          },
        );
      },
    );
  }
}

class _ContractCard extends StatelessWidget {
  final ContractModel contract;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContractCard({
    required this.contract,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: isSelected ? AppColors.primary.withOpacity(0.5) : AppColors.cardBorder,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.code_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '导入于 ${_formatDate(contract.importedAt)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (contract.isDeployed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.successGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '已部署',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.functions_rounded,
                label: '${_getFunctionCount(contract.abi)} 个函数',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.data_object_rounded,
                label: '${(contract.cleanBytecode.length ~/ 2)} 字节',
              ),
              if (contract.isDeployed) ...[
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.link_rounded,
                  label: '已部署',
                  color: AppColors.success,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  int _getFunctionCount(String abi) {
    try {
      final count = RegExp(r'"type"\s*:\s*"function"').allMatches(abi).length;
      return count;
    } catch (_) {
      return 0;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSecondary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (color ?? AppColors.cardBorder).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color ?? AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyContractView extends StatelessWidget {
  final VoidCallback onImportTap;

  const _EmptyContractView({required this.onImportTap});

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
              child: const Icon(Icons.code_off_rounded, size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text(
              '还没有合约',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '导入编译好的智能合约 ABI 和字节码\n即可一键部署到以太坊或 BSC',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: '导入合约',
              gradient: AppColors.cyanGradient,
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
              onPressed: onImportTap,
              width: 220,
            ),
          ],
        ),
      ),
    );
  }
}
