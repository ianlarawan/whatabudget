import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static const _databaseName = "FinanceTracker.db";
  static const _databaseVersion = 4;

  static const tableTransactions = 'transactions';
  static const tableCategories = 'categories';
  static const tableAccounts = 'accounts';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> replaceDatabase(String sourcePath) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDirectory.path, _databaseName);
    
    final sourceFile = File(sourcePath);
    await sourceFile.copy(dbPath);
    
    _database = await _initDatabase();
  }
  
  Future<String> getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS $tableTransactions');
    await db.execute('DROP TABLE IF EXISTS $tableAccounts');
    await db.execute('DROP TABLE IF EXISTS $tableCategories');
    await _onCreate(db, newVersion);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableAccounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        provider TEXT NOT NULL,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        goal_balance REAL,
        interest_rate REAL,
        card_network TEXT,
        credit_limit REAL,
        cash_advance_limit REAL,
        billing_date INTEGER,
        due_date_offset INTEGER,
        icon TEXT DEFAULT '🏦',
        include_in_net_worth INTEGER DEFAULT 1,
        interest_frequency TEXT DEFAULT 'none',
        interest_tiers TEXT,
        accumulated_interest REAL DEFAULT 0.0,
        last_interest_date INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        is_installment INTEGER DEFAULT 0,
        installment_total INTEGER,
        installment_current INTEGER,
        FOREIGN KEY (category_id) REFERENCES $tableCategories (id),
        FOREIGN KEY (account_id) REFERENCES $tableAccounts (id)
      )
    ''');

    await db.execute('''
      INSERT INTO $tableCategories (name, icon, type) VALUES
      ('Balance Adjustment', '⚖️', 'expense'), ('Family Support', '👨‍👩‍👧‍👦', 'expense'),
      ('Food and Drinks', '🍔', 'expense'), ('Gifts', '🎁', 'expense'),
      ('Grocery', '🛒', 'expense'), ('Insurance Payment', '🛡️', 'expense'),
      ('Interest Charges', '📈', 'expense'), ('Late Payment Fee', '⏰', 'expense'),
      ('Medicine', '💊', 'expense'), ('Night out', '🍸', 'expense'),
      ('Pet', '🐶', 'expense'), ('Rent', '🏠', 'expense'),
      ('Shopping', '🛍️', 'expense'), ('Subscriptions', '🔁', 'expense'),
      ('Transaction Fee', '💸', 'expense'), ('Transfer Fee', '🏦', 'expense'),
      ('Transportation', '🚗', 'expense'), ('Utilities', '💡', 'expense'),
      ('Witholding Tax', '🧾', 'expense'), ('Credit/Loan Bill Payment', '💳', 'expense'),
      ('Balance Adjustment', '⚖️', 'income'), ('Business', '🏢', 'income'),
      ('Cashback', '💰', 'income'), ('Company bonus', '🎉', 'income'),
      ('Content Creation', '🎥', 'income'), ('Freelance work', '💻', 'income'),
      ('Refund', '↩️', 'income'), ('Salary', '💵', 'income'),
      ('Savings Interest', '🏦', 'income'), ('Side hustle', '🚀', 'income')
    ''');
  }
}