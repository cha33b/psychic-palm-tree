import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/services/database_service.dart';
import 'package:worker_salary_manager/modules/settings/settings_service.dart';

/// Available currencies for payroll / salary display.
const List<String> kCurrencies = ['DA', 'USD', 'EUR', 'GBP'];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currency = 'DA';
  ThemeMode _themeMode = ThemeMode.light;
  bool _busy = false;
  bool _ready = false;
  bool _pinEnabled = false;
  String _pinCode = '';
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await SettingsService.instance.load();

    if (!mounted) return;

    setState(() {
      _currency = SettingsService.instance.currency.value;
      _themeMode = SettingsService.instance.themeMode.value;
      _pinEnabled = SettingsService.instance.pinEnabled.value;
      _pinCode = SettingsService.instance.pinCode.value;
      _ready = true;
    });
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await SettingsService.instance.saveTheme(mode);
  }

  Future<void> _saveCurrency(String code) async {
    setState(() => _currency = code);
    await SettingsService.instance.saveCurrency(code);
  }

  Future<void> _togglePinEnabled(bool enabled) async {
    if (enabled && _pinCode.isEmpty) {
      // Need to set PIN first
      _showPinSetupDialog(true);
      return;
    }
    setState(() => _pinEnabled = enabled);
    await SettingsService.instance.setPinEnabled(enabled);
  }

  Future<void> _changePin() async {
    _showPinSetupDialog(false);
  }

  Future<void> _showPinSetupDialog(bool isInitialSetup) async {
    _pinController.clear();
    _confirmPinController.clear();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isInitialSetup,
      builder: (dialogContext) => ContentDialog(
        title: Text(isInitialSetup ? 'Set Up PIN' : 'Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a 4-6 digit PIN:'),
            const SizedBox(height: 8),
            TextBox(
              controller: _pinController,
              placeholder: 'Enter PIN',
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 12),
            const Text('Confirm PIN:'),
            const SizedBox(height: 8),
            TextBox(
              controller: _confirmPinController,
              placeholder: 'Confirm PIN',
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          if (!isInitialSetup)
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.isEmpty || confirm.isEmpty) {
      _showError('PIN cannot be empty');
      return;
    }

    if (pin.length < 4 || pin.length > 6) {
      _showError('PIN must be 4-6 digits');
      return;
    }

    if (pin != confirm) {
      _showError('PINs do not match');
      return;
    }

    setState(() {
      _pinCode = pin;
      _pinEnabled = true;
    });
    await SettingsService.instance.setPinCode(pin);
    await SettingsService.instance.setPinEnabled(true);
  }

  void _showError(String message) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Error'),
        content: Text(message),
        severity: InfoBarSeverity.error,
      ),
    );
  }

  Future<void> _exportDatabase() async {
    setState(() => _busy = true);

    try {
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save database backup',
        fileName: 'salary_manager_backup.db',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      );

      if (result == null || result.isEmpty) {
        return;
      }

      await DatabaseService.instance.exportDatabase(context, result);

      if (!mounted) return;

      if (!context.mounted) return;
      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('Backup'),
          content: Text('Database exported successfully.'),
          severity: InfoBarSeverity.success,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;

      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Error'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importDatabase() async {
    setState(() => _busy = true);

    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select database backup to import',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        throw Exception('Could not read file path');
      }

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Confirm Import'),
          content: const Text(
            'Importing will REPLACE the current database with the backup. '
            'This action cannot be undone. Are you sure you want to continue?',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }

      await DatabaseService.instance.importDatabase(context, filePath);

      if (!mounted) return;

      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('Import'),
          content: Text('Database imported successfully. Please restart the app.'),
          severity: InfoBarSeverity.success,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;

      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Error'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ScaffoldPage(
        header: PageHeader(title: Text('Settings')),
        content: Center(child: ProgressRing()),
      );
    }

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Settings'),
        commandBar: _busy ? const ProgressRing(strokeWidth: 2) : null,
      ),
      content: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ------------------------------------------------------------
          // PIN LOCK
          // ------------------------------------------------------------
          const Text(
            'Security',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ToggleSwitch(
            content: const Text('Enable PIN Lock'),
            checked: _pinEnabled,
            onChanged: _togglePinEnabled,
          ),
          if (_pinEnabled) ...[
            const SizedBox(height: 8),
            Button(
              onPressed: _changePin,
              child: const Text('Change PIN'),
            ),
          ],
          const SizedBox(height: 32),

          // ------------------------------------------------------------
          // THEME
          // ------------------------------------------------------------
          const Text(
            'Appearance',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ComboBox<ThemeMode>(
            value: _themeMode,
            items: const [
              ComboBoxItem(value: ThemeMode.light, child: Text('Light')),
              ComboBoxItem(value: ThemeMode.dark, child: Text('Dark')),
              ComboBoxItem(value: ThemeMode.system, child: Text('System')),
            ],
            onChanged: (mode) {
              if (mode == null) return;
              _saveTheme(mode);
            },
          ),

          const SizedBox(height: 32),

          // ------------------------------------------------------------
          // CURRENCY
          // ------------------------------------------------------------
          const Text(
            'Currency',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ComboBox<String>(
            value: _currency,
            items: kCurrencies
                .map((c) => ComboBoxItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (code) {
              if (code == null) return;
              _saveCurrency(code);
            },
          ),

          const SizedBox(height: 32),

          // ------------------------------------------------------------
          // DATABASE BACKUP
          // ------------------------------------------------------------
          const Text(
            'Database',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Button(
            onPressed: _busy ? null : _exportDatabase,
            child: const Text('Export database backup...'),
          ),
          const SizedBox(height: 8),
          Button(
            onPressed: _busy ? null : _importDatabase,
            child: const Text('Import database backup...'),
          ),
        ],
      ),
    );
  }
}