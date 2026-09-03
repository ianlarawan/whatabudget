import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/category.dart';
import '../domain/models/transaction_item.dart';
import '../domain/models/account.dart';
import '../data/finance_repository.dart';
import '../data/database_helper.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository());

final categoriesProvider = AsyncNotifierProvider<CategoryNotifier, List<Category>>(() => CategoryNotifier());

class CategoryNotifier extends AsyncNotifier<List<Category>> {
  @override
  FutureOr<List<Category>> build() async => ref.read(financeRepositoryProvider).getCategories();

  Future<void> addCategory(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(financeRepositoryProvider).insertCategory(category);
      return ref.read(financeRepositoryProvider).getCategories();
    });
  }

  Future<void> updateCategory(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(financeRepositoryProvider).updateCategory(category);
      return ref.read(financeRepositoryProvider).getCategories();
    });
  }

  Future<void> deleteCategory(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(financeRepositoryProvider).deleteCategory(id);
      return ref.read(financeRepositoryProvider).getCategories();
    });
  }
}

final accountsProvider = AsyncNotifierProvider<AccountNotifier, List<Account>>(() => AccountNotifier());

class AccountNotifier extends AsyncNotifier<List<Account>> {
  @override
  FutureOr<List<Account>> build() async => ref.read(financeRepositoryProvider).getAccounts();

  Future<void> addAccount(Account account, {double? prevBalance, double? currBalance}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      await repository.insertAccount(account);
      
      final accounts = await repository.getAccounts();
      final newAcc = accounts.last;
      final cats = await repository.getCategories();
      final adjCat = cats.firstWhere((c) => c.name == 'Balance Adjustment', orElse: () => cats.first);

      if (['Credit', 'Loans'].contains(newAcc.type)) {
        final now = DateTime.now();
        final int billDay = newAcc.billingDate ?? 1;

        if (prevBalance != null && prevBalance > 0) {
          final prevBillingDate = DateTime(now.year, now.month - 1, billDay);
          final historicalDate = prevBillingDate.subtract(const Duration(days: 1));

          await repository.insertTransaction(TransactionItem(
            amount: prevBalance,
            type: 'expense',
            categoryId: adjCat.id!,
            accountId: newAcc.id!,
            date: historicalDate.millisecondsSinceEpoch,
            note: 'Initial Balance (Previous Statement)'
          ));
        }

        if (currBalance != null && currBalance > 0) {
          await repository.insertTransaction(TransactionItem(
            amount: currBalance,
            type: 'expense',
            categoryId: adjCat.id!,
            accountId: newAcc.id!,
            date: now.millisecondsSinceEpoch,
            note: 'Initial Balance (Current Statement)'
          ));
        }
      } else {
        if (newAcc.balance > 0) {
          final adjCat = cats.firstWhere((c) => c.name == 'Balance Adjustment' && c.type == 'income', orElse: () => cats.first);
          await repository.insertTransaction(TransactionItem(
            amount: newAcc.balance, type: 'income', categoryId: adjCat.id!, accountId: newAcc.id!, 
            date: DateTime.now().millisecondsSinceEpoch, note: 'Initial Balance'
          ));
        }
      }
      ref.invalidate(transactionsProvider);
      return repository.getAccounts();
    });
  }

  Future<void> updateAccount(Account updatedAccount, {double? oldBalance}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      if (oldBalance != null && updatedAccount.balance != oldBalance) {
        double delta = updatedAccount.balance - oldBalance;
        bool isDebt = ['Credit', 'Loans'].contains(updatedAccount.type);
        String txType = isDebt ? (delta > 0 ? 'expense' : 'income') : (delta > 0 ? 'income' : 'expense');
        
        final cats = await repository.getCategories();
        final adjCat = cats.firstWhere((c) => c.name == 'Balance Adjustment' && c.type == txType, orElse: () => cats.first);

        await repository.insertTransaction(TransactionItem(
          amount: delta.abs(), 
          type: txType, 
          categoryId: adjCat.id!, 
          accountId: updatedAccount.id!, 
          date: DateTime.now().millisecondsSinceEpoch, 
          note: 'Balance Adjustment'
        ));
        ref.invalidate(transactionsProvider);
      }
      await repository.updateAccount(updatedAccount);
      return repository.getAccounts();
    });
  }

  Future<void> deleteAccount(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      final db = await repository.dbHelper.database;
      await db.delete(DatabaseHelper.tableTransactions, where: 'account_id = ?', whereArgs: [id]);
      await db.delete(DatabaseHelper.tableAccounts, where: 'id = ?', whereArgs: [id]);
      ref.invalidate(transactionsProvider);
      return repository.getAccounts();
    });
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionNotifier, List<TransactionItem>>(() => TransactionNotifier());

class TransactionNotifier extends AsyncNotifier<List<TransactionItem>> {
  @override
  FutureOr<List<TransactionItem>> build() async => ref.read(financeRepositoryProvider).getTransactions();

  Future<void> addTransaction(TransactionItem transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      
      // Automatically array-ify incoming installments if added manually
      if (transaction.isInstallment && transaction.installmentTotal != null && transaction.installmentTotal! > 1) {
        final int totalMonths = transaction.installmentTotal!;
        final DateTime purchaseDate = DateTime.fromMillisecondsSinceEpoch(transaction.date);

        for (int i = 0; i < totalMonths; i++) {
          final futureDate = DateTime(purchaseDate.year, purchaseDate.month + i, purchaseDate.day);
          
          final distributedTx = TransactionItem(
            amount: transaction.amount, 
            type: transaction.type,
            categoryId: transaction.categoryId,
            accountId: transaction.accountId,
            date: futureDate.millisecondsSinceEpoch,
            note: transaction.note,
            isInstallment: true,
            installmentTotal: totalMonths,
            installmentCurrent: i,
          );
          
          await repository.insertTransaction(distributedTx);
          await _applyTransactionImpact(repository, distributedTx, isRevert: false);
        }
      } else {
        await repository.insertTransaction(transaction);
        await _applyTransactionImpact(repository, transaction, isRevert: false);
      }
      
      ref.invalidate(accountsProvider);
      return repository.getTransactions();
    });
  }

  Future<void> addTransfer({required int sourceId, required int destId, required double amount, required double fee, required int date, String note = 'Transfer', String categoryName = 'Balance Adjustment'}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      final cats = await repository.getCategories();
      final feeCat = cats.firstWhere((c) => c.name == 'Transfer Fee' && c.type == 'expense', orElse: () => cats.first);
      final outCat = cats.firstWhere((c) => c.name == categoryName && c.type == 'expense', orElse: () => cats.first);
      final inCat = cats.firstWhere((c) => c.name == 'Balance Adjustment' && c.type == 'income', orElse: () => cats.first);

      final accounts = await repository.getAccounts();
      final destAcc = accounts.firstWhere((a) => a.id == destId);
      final srcAcc = accounts.firstWhere((a) => a.id == sourceId);

      final actualNote = note == 'Transfer' ? 'Transfer to ${destAcc.name}' : note;
      final actualInNote = note == 'Transfer' ? 'Transfer from ${srcAcc.name}' : note;

      final outTx = TransactionItem(amount: amount, type: 'expense', categoryId: outCat.id!, accountId: sourceId, date: date, note: actualNote);
      await repository.insertTransaction(outTx);
      await _applyTransactionImpact(repository, outTx, isRevert: false);

      if (fee > 0) {
        final feeTx = TransactionItem(amount: fee, type: 'expense', categoryId: feeCat.id!, accountId: sourceId, date: date, note: 'Transfer Fee');
        await repository.insertTransaction(feeTx);
        await _applyTransactionImpact(repository, feeTx, isRevert: false);
      }

      final inTx = TransactionItem(amount: amount, type: 'income', categoryId: inCat.id!, accountId: destId, date: date, note: actualInNote);
      await repository.insertTransaction(inTx);
      await _applyTransactionImpact(repository, inTx, isRevert: false);

      ref.invalidate(accountsProvider);
      return repository.getTransactions();
    });
  }

  Future<void> updateTransaction(TransactionItem updatedTx) async {
    final currentTxs = state.value ?? [];
    final oldTx = currentTxs.firstWhere((t) => t.id == updatedTx.id);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      await _applyTransactionImpact(repository, oldTx, isRevert: true);
      await _applyTransactionImpact(repository, updatedTx, isRevert: false);
      await repository.updateTransaction(updatedTx);
      ref.invalidate(accountsProvider);
      return repository.getTransactions();
    });
  }

  Future<void> deleteTransaction(int id) async {
    final currentTxs = state.value ?? [];
    final txToDelete = currentTxs.firstWhere((t) => t.id == id);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      await repository.deleteTransaction(id);
      await _applyTransactionImpact(repository, txToDelete, isRevert: true);
      ref.invalidate(accountsProvider);
      return repository.getTransactions();
    });
  }

  Future<void> updateInstallmentPlan({
    required TransactionItem baseTx,
    required List<double> exactAmounts,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      final currentTxs = await repository.getTransactions();
      
      final relatedTxs = currentTxs.where((t) => 
        t.accountId == baseTx.accountId &&
        t.isInstallment == true &&
        t.note == baseTx.note && 
        t.installmentTotal == baseTx.installmentTotal
      ).toList();

      for (var tx in relatedTxs) {
        await _applyTransactionImpact(repository, tx, isRevert: true);
        await repository.deleteTransaction(tx.id!);
      }

      final firstLeg = relatedTxs.isNotEmpty 
          ? relatedTxs.reduce((a, b) => (a.installmentCurrent ?? 0) < (b.installmentCurrent ?? 0) ? a : b) 
          : baseTx;
      final DateTime originalDate = DateTime.fromMillisecondsSinceEpoch(firstLeg.date);
      final int newTenure = exactAmounts.length;

      for (int i = 0; i < newTenure; i++) {
        final futureDate = DateTime(originalDate.year, originalDate.month + i, originalDate.day);
        
        // Scale the exact manual amount up by the tenure length.
        // When the legacy impact engine divides this by the tenure, it yields the exact manual input.
        final scaledAmount = exactAmounts[i] * newTenure;

        final newTx = TransactionItem(
          amount: scaledAmount,
          type: baseTx.type,
          categoryId: baseTx.categoryId,
          accountId: baseTx.accountId,
          date: futureDate.millisecondsSinceEpoch,
          note: baseTx.note,
          isInstallment: true,
          installmentTotal: newTenure,
          installmentCurrent: i,
        );
        await repository.insertTransaction(newTx);
        await _applyTransactionImpact(repository, newTx, isRevert: false);
      }

      ref.invalidate(accountsProvider);
      return repository.getTransactions();
    });
  }

  Future<void> _applyTransactionImpact(FinanceRepository repository, TransactionItem tx, {required bool isRevert}) async {
    final accounts = await repository.getAccounts();
    try {
      final account = accounts.firstWhere((a) => a.id == tx.accountId);
      
      double impactAmount = tx.amount;
      if (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) {
        impactAmount = tx.amount / tx.installmentTotal!; 
      }

      double balanceDelta = impactAmount;
      if (['Credit', 'Loans'].contains(account.type)) {
        balanceDelta = (tx.type == 'expense') ? impactAmount : -impactAmount;
      } else {
        balanceDelta = (tx.type == 'income') ? impactAmount : -impactAmount;
      }

      if (isRevert) balanceDelta = -balanceDelta;

      final updatedAccount = Account(
        id: account.id, type: account.type, provider: account.provider, name: account.name,
        balance: account.balance + balanceDelta, goalBalance: account.goalBalance, interestRate: account.interestRate,
        cardNetwork: account.cardNetwork, creditLimit: account.creditLimit,
        cashAdvanceLimit: account.cashAdvanceLimit, billingDate: account.billingDate, dueDateOffset: account.dueDateOffset,
        icon: account.icon, includeInNetWorth: account.includeInNetWorth,
        interestFrequency: account.interestFrequency, interestTiers: account.interestTiers,
        accumulatedInterest: account.accumulatedInterest, lastInterestDate: account.lastInterestDate,
      );
      await repository.updateAccount(updatedAccount);
    } catch (_) {} 
  }
  Future<void> addInstallmentTransaction(TransactionItem baseTx) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(financeRepositoryProvider);
      final int totalMonths = baseTx.installmentTotal ?? 1;
      final DateTime purchaseDate = DateTime.fromMillisecondsSinceEpoch(baseTx.date);

      for (int i = 0; i < totalMonths; i++) {
        final futureDate = DateTime(purchaseDate.year, purchaseDate.month + i, purchaseDate.day);
        
        final distributedTx = TransactionItem(
          amount: baseTx.amount, 
          type: baseTx.type,
          categoryId: baseTx.categoryId,
          accountId: baseTx.accountId,
          date: futureDate.millisecondsSinceEpoch,
          note: baseTx.note,
          isInstallment: true,
          installmentTotal: totalMonths,
          installmentCurrent: i,
        );
        
        await repository.insertTransaction(distributedTx);
        await _applyTransactionImpact(repository, distributedTx, isRevert: false);
      }
      
      ref.invalidate(accountsProvider);
      return repository.getTransactions();
    });
  }
}