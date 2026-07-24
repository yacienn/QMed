import 'package:flutter/material.dart';
import 'package:quiz/core/theme/app_theme.dart';

class NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon; // Add this
  final Function(String)? onChanged;

  const NeoTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon, // Add this
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: AppTheme.neoBlack,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.neoBlack,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.neoBlack,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    prefixIcon,
                    color: AppTheme.neoBlack,
                    size: 22,
                  ),
                ),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.neoBlack,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: InputBorder.none,
                    suffixIcon: suffixIcon, // Add this
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}