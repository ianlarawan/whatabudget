import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'; // Added dependency for correct directory mapping
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../state/theme_provider.dart';
import '../state/providers.dart';

class BackupService {
  // FIXED: Adjusted to match the precise uppercase name case managed by your DatabaseHelper
  static const String _dbName = 'FinanceTracker.db';

  /// Resolves the absolute path targeting your real operational database file location
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

      final String targetFileName = _generateBackupFileName();
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Your Wallet Backup',
        fileName: targetFileName,
        type: FileType.any,
      );

      if (outputFile == null) return false; 

      await sourceFile.copy(outputFile);
      return true;
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

      // 1. Force close connection pointers safely
      final repo = ref.read(financeRepositoryProvider);
      await repo.dbHelper.closeDatabase();
      
      // 2. Clear out transactional lock buffers at the exact file coordinates
      final walFile = File('$targetLocation-wal');
      final shmFile = File('$targetLocation-shm');
      
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      
      await deleteDatabase(targetLocation);

      // 3. Write backup stream directly on top of the correct file slot
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