import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/gradient_button.dart';

class ImportWalletSheet extends StatefulWidget {
  const ImportWalletSheet({super.key});

  @override
  State<ImportWalletSheet> createState() => _ImportWalletSheetState();
}

class _ImportWalletSheetState extends State<ImportWalletSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _nameCtrl = TextEditingController(text: '导入的钱包');
  final _pkCtrl = TextEditingController();
  final _mnemonicCtrl = TextEditingController();
  final _pkFormKey = GlobalKey<FormState>();
  final _mnemonicFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePk = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _pkCtrl.dispose();
    _mnemonicCtrl.dispose();
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const Text(
              '导入钱包',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '通过私钥或助记词导入现有钱包',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '钱包名称',
                prefixIcon: Icon(Icons.label_outline_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabCtrl,
                dividerColor: Colors.transparent,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: '私钥导入'),
                  Tab(text: '助记词导入'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildPrivateKeyForm(),
                  _buildMnemonicForm(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: '导入钱包',
              icon: const Icon(Icons.download_rounded,
                  color: Colors.white, size: 20),
              isLoading: _isLoading,
              onPressed: _import,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateKeyForm() {
    return Form(
      key: _pkFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _pkCtrl,
            obscureText: _obscurePk,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: '私钥（64位十六进制）',
              hintText: '0x 开头或直接输入64位hex',
              prefixIcon: const Icon(Icons.key_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePk = !_obscurePk),
                icon: Icon(
                  _obscurePk
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入私钥';
              String key = v.trim();
              if (key.startsWith('0x') || key.startsWith('0X')) {
                key = key.substring(2);
              }
              if (key.length != 64) return '私钥应为64位十六进制字符串';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded,
                    color: AppColors.warning, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '私钥仅存储在本地加密安全区，不会上传到任何服务器',
                    style: TextStyle(color: AppColors.warning, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicForm() {
    return Form(
      key: _mnemonicFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _mnemonicCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              labelText: '助记词（12或24个单词）',
              hintText: '用空格分隔单词',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.format_quote_rounded,
                    color: AppColors.textSecondary),
              ),
              alignLabelWithHint: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入助记词';
              final words = v.trim().split(RegExp(r'\s+'));
              if (words.length != 12 && words.length != 24) {
                return '助记词应为12或24个单词';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final name = _nameCtrl.text.trim().isEmpty
        ? '导入的钱包'
        : _nameCtrl.text.trim();
    setState(() => _isLoading = true);

    try {
      final wp = context.read<WalletProvider>();
      if (_tabCtrl.index == 0) {
        if (!_pkFormKey.currentState!.validate()) {
          setState(() => _isLoading = false);
          return;
        }
        await wp.importFromPrivateKey(name, _pkCtrl.text.trim());
      } else {
        if (!_mnemonicFormKey.currentState!.validate()) {
          setState(() => _isLoading = false);
          return;
        }
        await wp.importFromMnemonic(name, _mnemonicCtrl.text.trim());
      }

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text('钱包导入成功'),
              ],
            ),
            backgroundColor: AppColors.card,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('导入失败: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
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
