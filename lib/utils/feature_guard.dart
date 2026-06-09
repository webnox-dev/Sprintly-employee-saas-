import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class FeatureGuard {
  /// Check if the organization has access to the specified feature.
  static bool hasFeature(String featureKey) {
    final storage = LocalStorageService();
    final planFeaturesStr = storage.planFeatures;

    if (planFeaturesStr.isNotEmpty && planFeaturesStr != '{}') {
      try {
        final features = jsonDecode(planFeaturesStr) as Map<String, dynamic>;
        return features[featureKey] == true;
      } catch (e) {
        debugPrint('Error parsing plan features: $e');
        return true; // Fallback to true on parse error
      }
    }
    return true; // Default to true if not loaded yet / not SaaS
  }

  /// Checks if the organization has access to the specified feature.
  /// If true, executes [onAccess].
  /// If false, shows an "Access Denied" dialog.
  static void checkFeature({
    required BuildContext context,
    required String featureKey,
    required VoidCallback onAccess,
  }) {
    final storage = LocalStorageService();
    final planFeaturesStr = storage.planFeatures;

    if (planFeaturesStr.isNotEmpty && planFeaturesStr != '{}') {
      try {
        final features = jsonDecode(planFeaturesStr) as Map<String, dynamic>;
        final hasAccess = features[featureKey] == true;
        
        if (!hasAccess) {
          _showAccessDeniedDialog(context);
          return;
        }
      } catch (e) {
        debugPrint('Error parsing plan features: $e');
      }
    }

    // Access granted
    onAccess();
  }

  static void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              const Text('Feature Locked'),
            ],
          ),
          content: const Text(
            'This feature is not included in your organization\'s current plan.\n\n'
            'Please contact your Admin to upgrade the plan.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Understood'),
            ),
          ],
        );
      },
    );
  }
}
