import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../domain/models/account.dart';
import '../domain/models/transaction_item.dart';
import '../domain/models/interest_tier.dart';
import '../data/finance_repository.dart';

class InterestService {
  static Future<void> processPendingInterest(WidgetRef ref) async {
    final repo = ref.read(financeRepositoryProvider);
    final accounts = await repo.getAccounts();
    final cats = await repo.getCategories();
    
    final interestCat = cats.firstWhere((c) => c.name == 'Savings Interest' && c.type == 'income', orElse: () => cats.first);

    bool needsRefresh = false;

    for (var acc in accounts) {
      if (acc.type != 'Savings' || acc.interestFrequency == 'none' || acc.lastInterestDate == null) continue;

      DateTime lastDate = DateTime.fromMillisecondsSinceEpoch(acc.lastInterestDate!);
      DateTime now = DateTime.now();
      DateTime todayEOD = DateTime(now.year, now.month, now.day);
      DateTime processingDate = DateTime(lastDate.year, lastDate.month, lastDate.day).add(const Duration(days: 1));

      double currentWorkingBalance = acc.balance;
      double accumulated = acc.accumulatedInterest;
      int updatedLastDate = acc.lastInterestDate!;
      bool accChanged = false;

      while (processingDate.isBefore(todayEOD) || processingDate.isAtSameMomentAs(todayEOD)) {
        double eodBalance = await _getHistoricalBalance(repo, acc.id!, processingDate);
        double dailyRate = _getRateForBalance(eodBalance, acc.interestTiers) / 100 / 365;

        if (acc.interestFrequency == 'daily') {
          double dailyEarned = eodBalance * dailyRate;
          accumulated += dailyEarned;
          
          if (accumulated >= 0.01) {
            double netInterest = accumulated * 0.80; // Deduct 20% withholding tax
            
            await repo.insertTransaction(TransactionItem(
              amount: netInterest, type: 'income', categoryId: interestCat.id!,
              accountId: acc.id!, date: processingDate.millisecondsSinceEpoch, note: 'Daily Interest (Net of 20% Tax)'
            ));
            
            currentWorkingBalance += netInterest;
            accumulated = 0;
            accChanged = true;
            needsRefresh = true;
          }
        } 
        else if (acc.interestFrequency == 'monthly') {
          double dailyEarned = eodBalance * dailyRate;
          accumulated += dailyEarned;
          
          if (processingDate.day == 1 && accumulated >= 0.01) {
            double netInterest = accumulated * 0.80; // Deduct 20% withholding tax

            await repo.insertTransaction(TransactionItem(
              amount: netInterest, type: 'income', categoryId: interestCat.id!,
              accountId: acc.id!, date: processingDate.millisecondsSinceEpoch, note: 'Monthly Interest (Net of 20% Tax)'
            ));
            
            currentWorkingBalance += netInterest;
            accumulated = 0;
            accChanged = true;
            needsRefresh = true;
          }
        } 
        else if (acc.interestFrequency == 'monthly_adb') {
          if (processingDate.day == 1 && acc.interestRate != null && acc.interestRate! > 0) { 
            int daysInMonth = DateTime(processingDate.year, processingDate.month, 0).day;
            double rate = _getRateForBalance(acc.interestRate!, acc.interestTiers) / 100;
            double grossInterest = acc.interestRate! * rate * (daysInMonth / 365);

            if (grossInterest >= 0.01) {
              double netInterest = grossInterest * 0.80; // Deduct 20% withholding tax

              await repo.insertTransaction(TransactionItem(
                amount: netInterest, type: 'income', categoryId: interestCat.id!,
                accountId: acc.id!, date: processingDate.millisecondsSinceEpoch, note: 'Monthly ADB Interest (Net of 20% Tax)'
              ));
              
              currentWorkingBalance += netInterest;
              accChanged = true;
              needsRefresh = true;
            }
          }
        }

        updatedLastDate = processingDate.millisecondsSinceEpoch;
        processingDate = processingDate.add(const Duration(days: 1));
      }

      if (accChanged || updatedLastDate != acc.lastInterestDate) {
        final updatedAcc = Account(
          id: acc.id, type: acc.type, provider: acc.provider, name: acc.name, balance: currentWorkingBalance,
          goalBalance: acc.goalBalance, interestRate: acc.interestRate, cardNetwork: acc.cardNetwork,
          creditLimit: acc.creditLimit, cashAdvanceLimit: acc.cashAdvanceLimit, billingDate: acc.billingDate,
          dueDateOffset: acc.dueDateOffset, icon: acc.icon, includeInNetWorth: acc.includeInNetWorth,
          interestFrequency: acc.interestFrequency, interestTiers: acc.interestTiers,
          accumulatedInterest: accumulated, lastInterestDate: updatedLastDate,
        );
        await repo.updateAccount(updatedAcc);
      }
    }

    if (needsRefresh) {
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
    }
  }

  static double _getRateForBalance(double balance, List<InterestTier> tiers) {
    if (tiers.isEmpty) return 0.0;
    double applicableRate = 0.0;
    for (var tier in tiers) {
      if (balance >= tier.threshold) applicableRate = tier.rate;
    }
    return applicableRate;
  }

  static Future<double> _getHistoricalBalance(FinanceRepository repo, int accountId, DateTime date) async {
    final txs = await repo.getTransactions();
    double bal = 0;
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
    
    for (var t in txs.where((t) => t.accountId == accountId && t.date <= endOfDay)) {
      double amount = t.amount;
      if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) {
          amount = t.amount / t.installmentTotal!;
      }
      if (t.type == 'income') {
        bal += amount;
      } else {
        bal -= amount;
      }
    }
    return bal;
  }
}