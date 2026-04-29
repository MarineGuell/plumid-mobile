class AppConstants {
  // API Configuration
  // Emulator    → 10.0.2.2        (adresse spéciale émulateur Android)
  // Vrai appareil → IP WiFi du PC  (ex: 192.168.1.42)
  // ↓ Seule ligne à modifier pour changer l'hôte de dev
  static const String devHost = '172.20.10.3';
  static String get apiBaseUrl => 'http://$devHost:8000/api';
  static const String hfBaseUrl =
      'https://bakezechiel-image-recognition-api-1.hf.space';
  static const int apiTimeout = 30000; // 30 seconds

  // Image Configuration
  static const double maxImageSizeMB = 5.0;
  static const int imageQuality = 85;

  // Location Configuration
  static const double defaultLatitude = 48.8566; // Paris
  static const double defaultLongitude = 2.3522;
  static const double locationAccuracy = 100.0; // meters

  // Cache Configuration
  static const int maxCacheAge = 7; // days
  static const int maxHistoryItems = 100;

  // Prediction Configuration
  static const int topPredictionsCount = 5;
  static const double minConfidenceThreshold = 0.3;

  // App Info
  static const String appName = "Plum'ID";
  static const String appVersion = '1.0.0';

  // Legal URLs
  static const String privacyPolicyUrl = 'https://plum-id.com/privacy';
  static const String termsOfUseUrl = 'https://plum-id.com/terms';

  // Contact
  static const String contactEmail = 'contact@plum-id.com';

  // Spacing, Width, Height, ...
  static const double defaultPadding = 24.0;
  static const double defaultMargin = 16.0;
  static const double borderRadius = 8.0;
  static const double buttonHeight = 48.0;
  static const double iconSize = 24.0;
  static const double smallSpacing = 8.0;
  static const double middleSpacing = 12.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 30.0;
}
