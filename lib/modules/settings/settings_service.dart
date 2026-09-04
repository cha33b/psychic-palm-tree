import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/services/database_service.dart';

/// Singleton responsible for persisting and exposing user preferences
/// (application theme, reporting currency, and PIN lock) across the whole app.
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _keyTheme = 'theme_mode';
  static const _keyCurrency = 'currency';
  static const _keyPinEnabled = 'pin_enabled';
  static const _keyPinCode = 'pin_code';

  /// Holds the active theme so the app shell can rebuild when it changes.
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Holds the currency code (e.g. "DA", "USD") used in money displays.
  final ValueNotifier<String> currency = ValueNotifier<String>('DA');

  /// Holds whether PIN lock is enabled.
  final ValueNotifier<bool> pinEnabled = ValueNotifier<bool>(false);

  /// Holds the PIN code (stored as plain text for simplicity; in production use hashing).
  final ValueNotifier<String> pinCode = ValueNotifier<String>('');

  /// Load persisted preferences from the database. Safe to call multiple times.
  Future<void> load() async {
    try {
      final theme = await DatabaseService.instance.getSetting(_keyTheme);
      if (theme != null) {
        themeMode.value = _parseThemeMode(theme);
      }

      final curr = await DatabaseService.instance.getSetting(_keyCurrency);
      if (curr != null && curr.isNotEmpty) {
        currency.value = curr;
      }

      final pinEnabledStr = await DatabaseService.instance.getSetting(_keyPinEnabled);
      if (pinEnabledStr != null) {
        pinEnabled.value = pinEnabledStr == 'true';
      }

      final pinCodeStr = await DatabaseService.instance.getSetting(_keyPinCode);
      if (pinCodeStr != null) {
        pinCode.value = pinCodeStr;
      }
    } catch (_) {
      // Fall back to the defaults already present on the notifiers.
    }
  }

  Future<void> saveTheme(ThemeMode mode) async {
    themeMode.value = mode;
    await DatabaseService.instance.setSetting(_keyTheme, mode.name);
  }

  Future<void> saveCurrency(String code) async {
    currency.value = code;
    await DatabaseService.instance.setSetting(_keyCurrency, code);
  }

  Future<void> setPinEnabled(bool enabled) async {
    pinEnabled.value = enabled;
    await DatabaseService.instance.setSetting(_keyPinEnabled, enabled.toString());
  }

  Future<void> setPinCode(String code) async {
    pinCode.value = code;
    await DatabaseService.instance.setSetting(_keyPinCode, code);
  }

  static ThemeMode _parseThemeMode(String name) {
    switch (name) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}
