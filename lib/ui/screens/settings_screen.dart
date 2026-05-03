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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Data Management', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Manage Categories'),
            onTap: () => context.push('/categories'),
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