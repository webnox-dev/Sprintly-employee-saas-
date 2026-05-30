import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../helpers/common_strings.dart';
import 'package:toastification/toastification.dart';
import 'package:responsive_framework/responsive_framework.dart';

// Responsive Framework Extensions
extension ResponsiveExtensions on BuildContext {
  double get screenHeight => ResponsiveBreakpoints.of(this).screenHeight;
  double get screenWidth => ResponsiveBreakpoints.of(this).screenWidth;

  // Responsive breakpoint helpers
  bool get isMobile => ResponsiveBreakpoints.of(this).isMobile;
  bool get isTablet => ResponsiveBreakpoints.of(this).isTablet;
  bool get isDesktop => ResponsiveBreakpoints.of(this).isDesktop;

  // Responsive sizing helpers
  double get responsiveHeight => screenHeight;
  double get responsiveWidth => screenWidth;

  // Percentage-based sizing
  double heightPercent(double percent) => screenHeight * (percent / 100);
  double widthPercent(double percent) => screenWidth * (percent / 100);
}

// MediaQuery based responsive helpers
extension MediaQueryExtensions on BuildContext {
  double get mediaHeight => MediaQuery.of(this).size.height;
  double get mediaWidth => MediaQuery.of(this).size.width;

  // Responsive breakpoints
  bool get isMobileDevice => mediaWidth <= 600;
  bool get isTabletDevice => mediaWidth > 600 && mediaWidth <= 900;
  bool get isDesktopDevice => mediaWidth > 900;

  // Responsive sizing
  double get responsivePadding => isMobileDevice
      ? 16.0
      : isTabletDevice
          ? 20.0
          : 24.0;
  double get responsiveMargin => isMobileDevice
      ? 8.0
      : isTabletDevice
          ? 12.0
          : 16.0;
  double get responsiveRadius => isMobileDevice
      ? 8.0
      : isTabletDevice
          ? 10.0
          : 12.0;
}

extension DoubleExtensions on double {
  Widget get hGap => SizedBox(height: this);
  Widget get wGap => SizedBox(width: this);
}

extension IntExtensions on int {
  Widget get hGap => SizedBox(height: this.toDouble());
  Widget get wGap => SizedBox(width: this.toDouble());
}

Widget customTextWithClip({
  required String text,
  required Color textColor,
  required double fontSize,
  required FontWeight fontWeight,
  TextAlign textAlign = TextAlign.left,
  bool? isStriked,
  int? maxLines,
}) {
  return Text(
    text,
    textAlign: textAlign,
    overflow: TextOverflow.clip,
    maxLines: maxLines,
    style: TextStyle(
      color: textColor,
      fontWeight: fontWeight,
      fontFamily: primaryFontFamily,
      fontSize: fontSize,
      decoration:
          isStriked != null && isStriked ? TextDecoration.lineThrough : null,
      decorationThickness: isStriked != null && isStriked ? 3.0 : null,
    ),
  );
}

Widget customTextWithEllipsis({
  required String text,
  required Color textColor,
  required double fontSize,
  required FontWeight fontWeight,
  TextAlign textAlign = TextAlign.left,
  int? maxLines,
}) {
  return Text(
    text,
    textAlign: textAlign,
    overflow: TextOverflow.ellipsis,
    maxLines: maxLines ?? 1,
    style: TextStyle(
      color: textColor,
      fontWeight: fontWeight,
      fontFamily: primaryFontFamily,
      fontSize: fontSize,
    ),
  );
}

EdgeInsets _getToastMargin() {
  try {
    final context = Get.context;
    final double width;
    if (context != null) {
      width = MediaQuery.of(context).size.width;
    } else {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      width = view.physicalSize.width / view.devicePixelRatio;
    }
    if (width > 600) {
      final double sideMargin = (width - 320) / 2;
      return EdgeInsets.only(left: sideMargin, right: sideMargin, bottom: 24);
    }
  } catch (_) {}
  return const EdgeInsets.symmetric(horizontal: 16);
}

void showSuccess({required String text}) {
  toastification.show(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 6.0),
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
      title: Text(
        text,
        style: TextStyle(fontFamily: primaryFontFamily),
      ),
      showProgressBar: false,
      alignment: Alignment.bottomCenter,
      direction: TextDirection.ltr,
      margin: _getToastMargin());
}

void showInfo({required String text}) {
  toastification.show(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 6.0),
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
      title: Text(
        text,
        style: TextStyle(fontFamily: primaryFontFamily),
      ),
      showProgressBar: false,
      alignment: Alignment.bottomCenter,
      direction: TextDirection.ltr,
      margin: _getToastMargin());
}

void showError({required String text}) {
  toastification.show(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 6.0),
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
      title: Text(
        text,
        style: TextStyle(fontFamily: primaryFontFamily),
      ),
      showProgressBar: false,
      alignment: Alignment.bottomCenter,
      direction: TextDirection.ltr,
      margin: _getToastMargin());
}

void showWarning({required String text}) {
  toastification.show(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 6.0),
      type: ToastificationType.warning,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
      title: Text(
        text,
        style: TextStyle(fontFamily: primaryFontFamily),
      ),
      showProgressBar: false,
      alignment: Alignment.bottomCenter,
      direction: TextDirection.ltr,
      margin: _getToastMargin());
}

// Responsive button widget
Widget responsiveButton({
  required String text,
  required VoidCallback onPressed,
  required BuildContext context,
  Color? backgroundColor,
  Color? textColor,
  double? width,
  double? height,
  EdgeInsets? padding,
  BorderRadius? borderRadius,
  IconData? icon,
}) {
  final isMobile = context.mediaWidth <= 600;
  final isTablet = context.mediaWidth > 600 && context.mediaWidth <= 900;

  return SizedBox(
    width: width ?? (isMobile ? double.infinity : null),
    height: height ??
        (isMobile
            ? 48
            : isTablet
                ? 52
                : 56),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: isMobile
                  ? 16
                  : isTablet
                      ? 20
                      : 24,
              vertical: isMobile
                  ? 12
                  : isTablet
                      ? 14
                      : 16,
            ),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ??
              BorderRadius.circular(isMobile
                  ? 8
                  : isTablet
                      ? 10
                      : 12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 8 : 10),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: isMobile
                  ? 14
                  : isTablet
                      ? 15
                      : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// Responsive card widget
Widget responsiveCard({
  required Widget child,
  required BuildContext context,
  EdgeInsets? padding,
  EdgeInsets? margin,
  BorderRadius? borderRadius,
  Color? backgroundColor,
  BoxBorder? border,
  List<BoxShadow>? boxShadow,
}) {
  final isMobile = context.mediaWidth <= 600;
  final isTablet = context.mediaWidth > 600 && context.mediaWidth <= 900;

  return Container(
    margin: margin ??
        EdgeInsets.all(isMobile
            ? 8
            : isTablet
                ? 12
                : 16),
    padding: padding ??
        EdgeInsets.all(isMobile
            ? 12
            : isTablet
                ? 16
                : 20),
    decoration: BoxDecoration(
      color: backgroundColor ?? Theme.of(context).cardColor,
      borderRadius: borderRadius ??
          BorderRadius.circular(isMobile
              ? 8
              : isTablet
                  ? 10
                  : 12),
      border: border,
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: isMobile
                  ? 4
                  : isTablet
                      ? 6
                      : 8,
              offset: Offset(
                  0,
                  isMobile
                      ? 2
                      : isTablet
                          ? 3
                          : 4),
            ),
          ],
    ),
    child: child,
  );
}

// Theme-aware card widget
Widget themeAwareCard({
  required Widget child,
  required BuildContext context,
  EdgeInsets? padding,
  EdgeInsets? margin,
  BorderRadius? borderRadius,
  Color? backgroundColor,
  BoxBorder? border,
  List<BoxShadow>? boxShadow,
  double? elevation,
}) {
  return Container(
    margin: margin ?? const EdgeInsets.all(16),
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: backgroundColor ?? Theme.of(context).cardColor,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      border: border ??
          Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
    ),
    child: child,
  );
}

// Theme-aware text widget
Widget themeAwareText({
  required String text,
  required BuildContext context,
  TextStyle? style,
  TextAlign? textAlign,
  int? maxLines,
  TextOverflow? overflow,
}) {
  return Text(
    text,
    style: style ?? Theme.of(context).textTheme.bodyMedium,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

// Theme-aware icon widget
Widget themeAwareIcon({
  required IconData icon,
  required BuildContext context,
  double? size,
  Color? color,
}) {
  return Icon(
    icon,
    size: size ?? 24,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}

// Theme-aware button widget
Widget themeAwareButton({
  required String text,
  required VoidCallback onPressed,
  required BuildContext context,
  Color? backgroundColor,
  Color? textColor,
  double? width,
  double? height,
  EdgeInsets? padding,
  BorderRadius? borderRadius,
  IconData? icon,
  bool isOutlined = false,
}) {
  final buttonStyle = isOutlined
      ? OutlinedButton.styleFrom(
          foregroundColor: textColor ?? Theme.of(context).colorScheme.primary,
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        )
      : ElevatedButton.styleFrom(
          backgroundColor:
              backgroundColor ?? Theme.of(context).colorScheme.primary,
          foregroundColor: textColor ?? Theme.of(context).colorScheme.onPrimary,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        );

  final button = isOutlined
      ? OutlinedButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: _buildButtonContent(text, icon),
        )
      : ElevatedButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: _buildButtonContent(text, icon),
        );

  return SizedBox(
    width: width,
    height: height,
    child: button,
  );
}

Widget _buildButtonContent(String text, IconData? icon) {
  if (icon != null) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
  return Text(text);
}

// Theme-aware divider widget
Widget themeAwareDivider({
  required BuildContext context,
  double? thickness,
  double? height,
  EdgeInsets? margin,
}) {
  return Container(
    margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
    child: Divider(
      thickness: thickness ?? 1,
      height: height ?? 1,
      color: Theme.of(context).dividerColor,
    ),
  );
}

// Theme-aware chip widget
Widget themeAwareChip({
  required String label,
  required BuildContext context,
  Color? backgroundColor,
  Color? labelColor,
  IconData? icon,
  VoidCallback? onDeleted,
  bool isSelected = false,
}) {
  return Chip(
    label: Text(
      label,
      style: TextStyle(
        color: labelColor ??
            (isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface),
      ),
    ),
    backgroundColor: backgroundColor ??
        (isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface),
    avatar: icon != null
        ? Icon(
            icon,
            color: labelColor ??
                (isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface),
          )
        : null,
    onDeleted: onDeleted,
    deleteIcon: onDeleted != null
        ? Icon(
            Icons.close,
            color: labelColor ??
                (isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface),
          )
        : null,
  );
}
