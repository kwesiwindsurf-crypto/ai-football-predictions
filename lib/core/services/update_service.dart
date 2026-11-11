import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/app_theme.dart';

/// Play Store flexible update: downloads in the background while the app stays
/// usable, then offers a restart to install.
class UpdateService {
  static Future<void> checkForUpdates({BuildContext? context}) async {
    // The plugin only implements Android; every other target throws.
    if (kDebugMode || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();

      // A download finished in an earlier session but was never installed.
      if (info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          info.installStatus == InstallStatus.downloaded) {
        if (context != null && context.mounted) _promptRestart(context);
        return;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.flexibleUpdateAllowed) {
        return;
      }

      // Returns without throwing when the user dismisses Play's sheet.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return;

      if (context != null && context.mounted) _promptRestart(context);
    } catch (e) {
      debugPrint('[UpdateService] Native update failed: $e');
    }
  }

  /// A banner rather than a SnackBar: a persistent SnackBar would queue every
  /// other toast in the app behind it until the user restarts.
  static void _promptRestart(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppTheme.surfaceOf(context),
        leading: const Icon(Icons.system_update_alt_rounded,
            color: AppTheme.success),
        content: Text(
          'Update downloaded and ready to install',
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: Text(
              'LATER',
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              messenger.hideCurrentMaterialBanner();
              await InAppUpdate.completeFlexibleUpdate();
            },
            child: const Text(
              'RESTART',
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}