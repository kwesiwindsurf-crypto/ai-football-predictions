import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../theme/app_theme.dart';

/// Shared Style-4 ("Accent Pill Bar") header used across all 4 main tabs.
///
/// Reacts automatically to both `AppTheme.primaryOf(context)` (Accent Style)
/// and light/dark `ThemeMode` changes.
class AppTabHeader extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool includeTopSafeArea;

  const AppTabHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.includeTopSafeArea = true,
  });

  static const double contentHeight = 62.0;

  /// Wraps [AppTabHeader] as a `Scaffold.appBar` with room for status-bar insets.
  static PreferredSizeWidget asAppBar(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(topInset + contentHeight),
      child: AppTabHeader(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        includeTopSafeArea: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final primary = AppSettingsService.instance.accentColor;
        final surface = AppTheme.surfaceOf(context);
        final textPrimary = AppTheme.textPrimaryOf(context);
        final textSecondary = AppTheme.textSecondaryOf(context);
        final isDark = AppTheme.isDark(context);

        return Container(
          decoration: BoxDecoration(
            color: surface,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  primary.withValues(alpha: isDark ? 0.08 : 0.06),
                  surface,
                ),
                surface,
              ],
            ),
          ),
          child: SafeArea(
            top: includeTopSafeArea,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      // Style 4 circular tinted badge icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.14),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.35),
                            width: 1.1,
                          ),
                        ),
                        child: Center(
                          child: IconTheme(
                            data: IconThemeData(color: primary, size: 19),
                            child: icon,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      letterSpacing: -0.3,
                                      height: 1.15,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 10),
                        trailing!,
                      ],
                    ],
                  ),
                ),
                // Centered dynamic accent hairline
                Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        primary.withValues(alpha: 0.78),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact pill badge used in Style 4 headers (e.g. `AI`, `v3.4`).
class AppTabHeaderBadge extends StatelessWidget {
  final String label;

  const AppTabHeaderBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final primary = AppSettingsService.instance.accentColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: primary,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        );
      },
    );
  }
}

/// Circular 36x36 action button tinted consistently for Style 4 headers.
class AppTabHeaderAction extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool accentBorder;

  const AppTabHeaderAction({
    super.key,
    required this.child,
    this.onTap,
    this.accentBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final primary = AppSettingsService.instance.accentColor;
        final surface = AppTheme.surfaceOf(context);
        final borderColor = AppTheme.cardBorderOf(context);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface,
              border: Border.all(
                color: accentBorder ? primary.withValues(alpha: 0.4) : borderColor,
                width: accentBorder ? 1.2 : 1,
              ),
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

