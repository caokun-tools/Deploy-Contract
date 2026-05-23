import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_card.dart';

class ImportContractSheet extends StatefulWidget {
  const ImportContractSheet({super.key});

  @override
  State<ImportContractSheet> createState() => _ImportContractSheetState();
}

class _ImportContractSheetState extends State<ImportContractSheet> {
  final _nameCtrl = TextEditingController(text: 'MyContract');
  final _abiCtrl = TextEditingController();
  final _bytecodeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _abiFileName;
  String? _bytecodeFileName;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abiCtrl.dispose();
    _bytecodeCtrl.dispose();
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
      child: DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  '导入智能合约',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  '支持粘贴文本或选择文件导入',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Contract name
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: '合约名称',
                    prefixIcon: Icon(Icons.drive_file_rename_outline_rounded, color: AppColors.textSecondary),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? '请输入合约名称' : null,
                ),
                const SizedBox(height: 16),

                // ABI section
                _SectionLabel(title: 'ABI（JSON 数组格式）', icon: Icons.data_object_rounded),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(4),
                        borderColor: _abiCtrl.text.isNotEmpty
                            ? AppColors.secondary.withOpacity(0.5)
                            : AppColors.cardBorder,
                        child: TextFormField(
                          controller: _abiCtrl,
                          maxLines: 5,
                          style: AppTheme.monoStyle.copyWith(fontSize: 11),
                          decoration: const InputDecoration(
                            hintText: '[{"type":"function","name":"transfer",...}]',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(10),
                            hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 11),
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'ABI 不能为空';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FilePickerButton(
                  label: _abiFileName ?? '选择 ABI 文件 (.json)',
                  onTap: _pickAbiFile,
                ),
                const SizedBox(height: 16),

                // Bytecode section
                _SectionLabel(title: '字节码（十六进制）', icon: Icons.memory_rounded),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(4),
                  borderColor: _bytecodeCtrl.text.isNotEmpty
                      ? AppColors.secondary.withOpacity(0.5)
                      : AppColors.cardBorder,
                  child: TextFormField(
                    controller: _bytecodeCtrl,
                    maxLines: 4,
                    style: AppTheme.monoStyle.copyWith(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: '0x608060405234801561001057600080...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(10),
                      hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 11),
                    ),
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return '字节码不能为空';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                _FilePickerButton(
                  label: _bytecodeFileName ?? '选择字节码文件 (.bin/.txt)',
                  onTap: _pickBytecodeFile,
                ),

                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.info.withOpacity(0.3),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '字节码可从 Remix IDE / Hardhat / Truffle 编译产物中获取',
                          style: TextStyle(color: AppColors.info, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                GradientButton(
                  label: '导入合约',
                  gradient: AppColors.cyanGradient,
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  isLoading: _isLoading,
                  onPressed: _import,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAbiFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'abi'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String? content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }
    if (content != null && mounted) {
      setState(() {
        _abiCtrl.text = content!.trim();
        _abiFileName = file.name;
      });
    }
  }

  Future<void> _pickBytecodeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin', 'txt', 'hex'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String? content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }
    if (content != null && mounted) {
      setState(() {
        _bytecodeCtrl.text = content!.trim();
        _bytecodeFileName = file.name;
      });
    }
  }

  Future<void> _import() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final cp = context.read<ContractProvider>();
      await cp.addContract(
        name: _nameCtrl.text.trim(),
        abi: _abiCtrl.text.trim(),
        bytecode: _bytecodeCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text('合约导入成功'),
              ],
            ),
            backgroundColor: AppColors.card,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionLabel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FilePickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilePickerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.folder_open_rounded, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
