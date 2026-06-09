import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'session_expiry_service.dart';

class FeatureGuardService {
  static final FeatureGuardService _instance = FeatureGuardService._internal();
  factory FeatureGuardService() => _instance;
  FeatureGuardService._internal();

  bool _isHandlingFeatureLock = false;

  void handleFeatureLocked([String? message]) async {
    if (_isHandlingFeatureLock) return;
    _isHandlingFeatureLock = true;

    try {
      final context = SessionExpiryService().navigatorKey.currentContext;
      if (context != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.redAccent, size: 28),
                SizedBox(width: 8),
                Text('Feature Locked'),
              ],
            ),
            content: Text(message ?? "This feature is not available on your company's current plan."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  try {
                    Get.offAllNamed('/dashboard');
                  } catch (_) {
                    Navigator.of(context).pushReplacementNamed('/dashboard');
                  }
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        _isHandlingFeatureLock = false;
      });
    }
  }
}
