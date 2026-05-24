import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/theme_provider.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Section 1: Appearance
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme Mode'),
            trailing: DropdownButton<String>(
              value: currentTheme,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'System', child: Text('System Default')),
                DropdownMenuItem(value: 'Light', child: Text('Light')),
                DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                DropdownMenuItem(value: 'AMOLED Dark', child: Text('AMOLED Dark')),
              ],
              onChanged: (val) {
                if (val != null) ref.read(themeProvider.notifier).setTheme(val);
              },
            ),
          ),
          const Divider(),

          // Section 2: Preferences (Appropriate Home for Budgeting)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.wallet), // Color parameter stripped; naturally uses theme grey/neutral
            title: const Text('Configure Budget Targets'),
            subtitle: const Text('Set or reset your daily, weekly, or monthly spending limits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit-budget'),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Manage Categories'),
            subtitle: const Text('Create or customize transaction labels'),
            onTap: () => context.push('/categories'),
          ),
          const Divider(),

          // Section 3: Data Management (File Maintenance Only)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Data Management', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Data'),
            subtitle: const Text('Export database to a local file'),
            onTap: () async {
              bool success = await BackupService.exportBackup(); 
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Backup successful' : 'Backup failed or cancelled')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Data'),
            subtitle: const Text('Replace current database with a backup file'),
            onTap: () async {
              bool success = await BackupService.restoreBackup(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Restore successful. Restart recommended.' : 'Restore failed or cancelled')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}