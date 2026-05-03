import 'database_helper.dart';
import '../domain/models/category.dart';
import '../domain/models/transaction_item.dart';
import '../domain/models/account.dart';

class FinanceRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertCategory(Category category) async {
    final db = await dbHelper.database;
    return await db.insert(DatabaseHelper.tableCategories, category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await dbHelper.database;
    final maps = await db.query(DatabaseHelper.tableCategories);
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> insertTransaction(TransactionItem transaction) async {
    final db = await dbHelper.database;
    return await db.insert(DatabaseHelper.tableTransactions, transaction.toMap());
  }

  Future<List<TransactionItem>> getTransactions() async {
    final db = await dbHelper.database;
    final maps = await db.query(DatabaseHelper.tableTransactions, orderBy: 'date DESC');
    return maps.map((e) => TransactionItem.fromMap(e)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      DatabaseHelper.tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertAccount(Account account) async {
    final db = await dbHelper.database;
    return await db.insert(DatabaseHelper.tableAccounts, account.toMap());
  }

  Future<List<Account>> getAccounts() async {
    final db = await dbHelper.database;
    final maps = await db.query(DatabaseHelper.tableAccounts);
    return maps.map((e) => Account.fromMap(e)).toList();
  }

  Future<int> updateAccount(Account account) async {
    final db = await dbHelper.database;
    return await db.update(
      DatabaseHelper.tableAccounts,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> updateTransaction(TransactionItem transaction) async {
    final db = await dbHelper.database;
    return await db.update(
      DatabaseHelper.tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> updateCategory(Category category) async {
    final db = await dbHelper.database;
    return await db.update(DatabaseHelper.tableCategories, category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await dbHelper.database;
    return await db.delete(DatabaseHelper.tableCategories, where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getAccountBalanceAtDate(int accountId, int epochMillis) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> txs = await db.query(
      DatabaseHelper.tableTransactions,
      where: 'account_id = ? AND date <= ?',
      whereArgs: [accountId, epochMillis],
    );

    double historicalBalance = 0;
    // Note: Assuming initial balance is 0 and all funds originate from transactions.
    // If accounts have a starting balance decoupled from transactions, structural changes to the ledger are required.
    for (var tx in txs) {
      double amount = tx['amount'];
      String type = tx['type'];
      // Asset account logic (Savings/Wallet)
      if (type == 'income') historicalBalance += amount;
      if (type == 'expense') historicalBalance -= amount;
    }
    return historicalBalance;
  }
}