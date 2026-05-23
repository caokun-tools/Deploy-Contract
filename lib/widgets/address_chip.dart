import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AddressChip extends StatelessWidget {
  final String address;
  final bool full;
  final bool showCopy;
  final TextStyle? style;

  const AddressChip({
    super.key,
    required this.address,
    this.full = false,
    this.showCopy = true,
    this.style,
  });

  String get _display {
    if (full || address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showCopy ? () => _copy(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _display,
              style: style ??
                  GoogleFonts.robotoMono(
                    color: AppColors.textMono,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
            if (showCopy) ...[
              const SizedBox(width: 6),
              const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text('地址已复制', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.card,
      ),
    );
  }
}

class FullAddressBox extends StatelessWidget {
  final String address;
  final String? label;

  const FullAddressBox({super.key, required this.address, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.robotoMono(
                    color: AppColors.textMono,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
