// Application configuration using environment variables
// Use --dart-define to set these values at build time

import 'package:flutter/foundation.dart';

class AppConfig {
  /// Gemini API Key for AI food recommendations
  /// Set with: flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Application environment (development, staging, production)
  /// Set with: flutter run --dart-define=ENV=production
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// Base URL for Gemini API
  static const String geminiApiBaseUrl = String.fromEnvironment(
    'GEMINI_API_URL',
    defaultValue:
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent',
  );

  // Environment checks
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  // Feature flags based on environment
  static bool get enableDebugLogs => !isProduction;
  static bool get enableVerboseLogging => isDevelopment;

  // Validation
  static bool get hasValidGeminiApiKey =>
      geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_API_KEY_HERE';

  /// Get environment-specific app name
  static String get appName {
    switch (environment) {
      case 'development':
        return 'WellFasted (Dev)';
      case 'staging':
        return 'WellFasted (Staging)';
      case 'production':
      default:
        return 'WellFasted';
    }
  }

  /// Debug information
  static void printConfig() {
    if (enableDebugLogs) {
      debugPrint('=== App Configuration ===');
      debugPrint('Environment: $environment');
      debugPrint('App Name: $appName');
      debugPrint('Has Valid API Key: $hasValidGeminiApiKey');
      debugPrint('Debug Logs: $enableDebugLogs');
      debugPrint('Verbose Logs: $enableVerboseLogging');
      debugPrint('API URL: $geminiApiBaseUrl');
      debugPrint('========================');
    }
  }
}
