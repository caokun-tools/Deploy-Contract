import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_card.dart';

class CreateWalletSheet extends StatefulWidget {
  const CreateWalletSheet({super.key});

  @override
  State<CreateWalletSheet> createState() => _CreateWalletSheetState();
}

class _CreateWalletSheetState extends State<CreateWalletSheet> {
  final _nameCtrl = TextEditingController(text: '我的钱包');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _generatedMnemonic;
  String? _generatedAddress;
  bool _mnemonicCopied = false;
  bool _confirmed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _generatedMnemonic == null
          ? _buildNameForm()
          : _buildMnemonicDisplay(),
    );
  }

  Widget _buildNameForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 8),
            const Text(
              '创建新钱包',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '将自动生成 BIP39 助记词和 ERC-20 兼容地址',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '钱包名称',
                prefixIcon: Icon(Icons.label_outline_rounded, color: AppColors.textSecondary),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入钱包名称' : null,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: '生成钱包',
              icon: const Icon(Icons.generating_tokens_rounded, color: Colors.white, size: 20),
              isLoading: _isLoading,
              onPressed: _create,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMnemonicDisplay() {
    final words = _generatedMnemonic!.split(' ');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                '钱包创建成功',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.warning.withOpacity(0.5),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '请安全保存下方助记词，丢失将无法恢复钱包资产！',
                    style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '助记词（12个单词）',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: words.length,
              itemBuilder: (_, i) => Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${i + 1}.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      words[i],
                      style: const TextStyle(
                        color: AppColors.textMono,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _generatedMnemonic!));
              setState(() => _mnemonicCopied = true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _mnemonicCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                    size: 16,
                    color: _mnemonicCopied ? AppColors.success : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _mnemonicCopied ? '已复制到剪贴板' : '复制助记词',
                    style: TextStyle(
                      color: _mnemonicCopied ? AppColors.success : AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '钱包地址',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              _generatedAddress!,
              style: AppTheme.monoStyle.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _confirmed = !_confirmed),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _confirmed ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: _confirmed ? AppColors.primary : AppColors.cardBorder,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: _confirmed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '我已安全保存助记词，并了解丢失后无法恢复',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: '完成',
            onPressed: _confirmed ? _finish : null,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final wp = context.read<WalletProvider>();
      final result = await wp.createWallet(_nameCtrl.text.trim());
      final wallet = result.$1;
      final mnemonic = result.$2;
      setState(() {
        _generatedMnemonic = mnemonic;
        _generatedAddress = wallet.address;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _finish() {
    Navigator.pop(context, true);
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
