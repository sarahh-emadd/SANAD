import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixWidget;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffixWidget,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword ? _obscureText : false,
      validator: widget.validator,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppTheme.textDark,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(
          widget.prefixIcon,
          color: AppTheme.hintGrey,
          size: 20,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.hintGrey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : widget.suffixWidget,
      ),
    );
  }
}

class SplitTextField extends StatelessWidget {
  final String hintText1;
  final String hintText2;
  final TextEditingController? controller1;
  final TextEditingController? controller2;
  final String? Function(String?)? validator1;
  final String? Function(String?)? validator2;

  const SplitTextField({
    super.key,
    required this.hintText1,
    required this.hintText2,
    this.controller1,
    this.controller2,
    this.validator1,
    this.validator2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller1,
            validator: validator1,
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
            decoration: InputDecoration(
              hintText: hintText1,
              prefixIcon: const Icon(Icons.person_outline, color: AppTheme.hintGrey, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller2,
            validator: validator2,
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
            decoration: InputDecoration(
              hintText: hintText2,
              prefixIcon: const Icon(Icons.person_outline, color: AppTheme.hintGrey, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
