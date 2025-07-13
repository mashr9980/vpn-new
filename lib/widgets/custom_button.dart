import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonStyle? style;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.style,
    this.width,
    this.height,
    this.backgroundColor,
    this.textColor,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isOutlined ? _outlinedButtonStyle() : _elevatedButtonStyle();

    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height ?? 52,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: style ?? buttonStyle,
          child: _buildContent(),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height ?? 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style ?? buttonStyle,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlined ? AppColors.primary : AppColors.white,
              ),
            ),
          ),
          if (width == null || width! > 100) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Loading...',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: width != null && width! < 120 ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: isOutlined ? AppColors.primary : AppColors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: width != null && width! < 120 ? 16 : 18,
            color: textColor ?? (isOutlined ? AppColors.primary : AppColors.white),
          ),
          if (width == null || width! > 60) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: width != null && width! < 120 ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? (isOutlined ? AppColors.primary : AppColors.white),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: width != null && width! < 120 ? 12 : 14,
        fontWeight: FontWeight.w600,
        color: textColor ?? (isOutlined ? AppColors.primary : AppColors.white),
      ),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  ButtonStyle _elevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: textColor ?? AppColors.white,
      elevation: 2,
      shadowColor: AppColors.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: width != null && width! < 120 ? 8 : 16,
        vertical: height != null && height! < 40 ? 8 : 12,
      ),
    );
  }

  ButtonStyle _outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: textColor ?? AppColors.primary,
      side: BorderSide(
        color: backgroundColor ?? AppColors.primary,
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: width != null && width! < 120 ? 8 : 16,
        vertical: height != null && height! < 40 ? 8 : 12,
      ),
    );
  }
}