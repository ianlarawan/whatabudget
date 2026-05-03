import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database_helper.dart';
import '../state/providers.dart';

class BackupService {
  static Future<bool> exportBackup() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return false;

      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final destFile = File('$selectedDirectory/FinanceTracker_Backup_$timestamp.db');
      
      await dbFile.copy(destFile.path);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restoreBackup(WidgetRef ref) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) return false;

      final sourcePath = result.files.single.path!;
      await DatabaseHelper.instance.replaceDatabase(sourcePath);
      
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(categoriesProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> processAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = prefs.getString('backup_frequency') ?? 'none';
    if (frequency == 'none') return;

    final lastBackupStr = prefs.getString('last_auto_backup');
    DateTime? lastBackup = lastBackupStr != null ? DateTime.parse(lastBackupStr) : null;
    DateTime now = DateTime.now();

    bool shouldBackup = false;
    if (lastBackup == null) {
      shouldBackup = true;
    } else if (frequency == 'daily' && now.difference(lastBackup).inDays >= 1) {
      shouldBackup = true;
    } else if (frequency == 'weekly' && now.difference(lastBackup).inDays >= 7) {
      shouldBackup = true;
    } else if (frequency == 'monthly' && now.difference(lastBackup).inDays >= 30) {
      shouldBackup = true;
    }

    if (shouldBackup) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final backupDir = Directory('${docs.path}/AutoBackups');
        if (!await backupDir.exists()) await backupDir.create();

        final dbPath = await DatabaseHelper.instance.getDatabasePath();
        await File(dbPath).copy('${backupDir.path}/FinanceTracker_AutoBackup.db');
        await prefs.setString('last_auto_backup', now.toIso8601String());
      } catch (_) {}
    }
  }
}