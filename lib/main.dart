import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:worker_salary_manager/modules/dashboard/dashboard_page.dart';
import 'package:worker_salary_manager/modules/settings/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Configure the desktop window size, minimum size and title before the
    // first frame is rendered. Wrapped in a try/catch so a platform-specific
    // failure never prevents startup.
    try {
      await WindowManager.instance.waitUntilReadyToShow(
        WindowOptions(
          size: const Size(1280, 760),
          minimumSize: const Size(960, 600),
          title: 'Worker Salary Manager',
        ),
      );
    } catch (_) {}
  }

  // Load persisted user preferences (theme + currency + PIN) before the first frame
  // so the app shell starts with the correct theme.
  await SettingsService.instance.load();

  runApp(const SalaryManagerApp());
}

class SalaryManagerApp extends StatelessWidget {
  const SalaryManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the shell whenever the theme preference changes.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.instance.themeMode,
      builder: (context, themeMode, child) {
        return FluentApp(
          debugShowCheckedModeBanner: false,
          title: 'Worker Salary Manager',
          theme: FluentThemeData(
            brightness: Brightness.light,
            accentColor: Colors.blue,
          ),
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            accentColor: Colors.blue,
          ),
          themeMode: themeMode,
          home: const PinLockWrapper(),
        );
      },
    );
  }
}

/// Wrapper that shows PIN lock dialog if PIN is enabled, then shows the DashboardPage.
class PinLockWrapper extends StatefulWidget {
  const PinLockWrapper({super.key});

  @override
  State<PinLockWrapper> createState() => _PinLockWrapperState();
}

class _PinLockWrapperState extends State<PinLockWrapper> {
  bool _unlocked = false;
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPinLock();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkPinLock() async {
    final pinEnabled = SettingsService.instance.pinEnabled.value;
    if (!pinEnabled) {
      setState(() => _unlocked = true);
      return;
    }

    // Show PIN entry dialog
    await _showPinDialog();
  }

  Future<void> _showPinDialog() async {
    final storedPin = SettingsService.instance.pinCode.value;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ContentDialog(
        title: const Text('PIN Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your PIN to unlock the app:'),
            const SizedBox(height: 12),
            TextBox(
              controller: _pinController,
              placeholder: 'Enter PIN',
              obscureText: true,
              maxLength: 6,
              onSubmitted: (value) {
                Navigator.pop(dialogContext, value == storedPin);
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, _pinController.text == storedPin);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _unlocked = true;
        _pinController.clear();
      });
    } else {
      // Wrong PIN - show error and retry
      _pinController.clear();
      if (!mounted) return;
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Incorrect PIN'),
          content: const Text('Please try again.'),
          severity: InfoBarSeverity.error,
        ),
      );
      await _showPinDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      // Show a loading screen while PIN dialog is displayed
      return const ScaffoldPage(
        content: Center(child: ProgressRing()),
      );
    }
    return const DashboardPage();
  }
}
