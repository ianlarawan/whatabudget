import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../state/theme_provider.dart';
import '../state/providers.dart';

class BackupService {
  static const String _dbName = 'FinanceTracker.db';

  static Future<String> _getTargetDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, _dbName);
  }

  static String _generateBackupFileName() {
    final now = DateTime.now();
    final timestamp = DateFormat("yyyy-MM-dd'T'HH-mm-ss").format(now);
    return 'WAB_Backup_$timestamp.db';
  }

  static Future<bool> exportBackup() async {
    try {
      final targetLocation = await _getTargetDatabasePath();
      final sourceFile = File(targetLocation);

      if (!await sourceFile.exists()) return false;

      await _writePreferencesToDatabase();

      final tempDir = await getTemporaryDirectory();
      final backupFileName = _generateBackupFileName();
      final tempBackupPath = p.join(tempDir.path, backupFileName);
      
      final exportFile = await sourceFile.copy(tempBackupPath);

      final result = await Share.shareXFiles([XFile(exportFile.path)], text: 'What-A-Budget Database Backup');
      
      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restoreBackup(WidgetRef ref) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select WAB Backup File',
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final targetLocation = await _getTargetDatabasePath();

      final repo = ref.read(financeRepositoryProvider);
      await repo.dbHelper.closeDatabase();
      
      final walFile = File('$targetLocation-wal');
      final shmFile = File('$targetLocation-shm');
      
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      
      await deleteDatabase(targetLocation);

      final backupFile = File(result.files.single.path!);
      await backupFile.copy(targetLocation);

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> processAutoBackup() async {}

  static Future<void> _writePreferencesToDatabase() async {
    final targetLocation = await _getTargetDatabasePath();
    final db = await openDatabase(targetLocation);
    final prefs = await SharedPreferences.getInstance();
    
    final currentTheme = prefs.getString('theme_mode') ?? 'System';

    await db.execute('DROP TABLE IF EXISTS android_metadata;');
    await db.execute('CREATE TABLE android_metadata (locale TEXT);');
    await db.execute('INSERT INTO android_metadata (locale) VALUES (?);', [currentTheme]);
    await db.close();
  }
}