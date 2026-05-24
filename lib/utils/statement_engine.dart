import 'package:intl/intl.dart';
import '../../domain/models/account.dart';
import '../../domain/models/transaction_item.dart';

class Statement {
  final DateTime billingDate;
  final DateTime dueDate;
  final double totalAmount; 
  final double amountDue;   
  final List<TransactionItem> transactions;
  final String label;
  final bool isBilled;
  final bool isPaid;

  Statement({
    required this.billingDate,
    required this.dueDate,
    required this.totalAmount,
    required this.amountDue,
    required this.transactions,
    required this.label,
    required this.isBilled,
    required this.isPaid,
  });
}

class StatementEngine {
  static List<Statement> generateStatements({
    required Account account,
    required List<TransactionItem> transactions,
  }) {
    if (!['Credit', 'Loans'].contains(account.type) || account.billingDate == null) {
      return [];
    }

    final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int billDay = account.billingDate!;
    
    final accountTxs = transactions.where((t) => t.accountId == account.id).toList();
    
    DateTime currentBillCutoff = now.day >= billDay 
        ? DateTime(now.year, now.month, billDay)
        : DateTime(now.year, now.month - 1, billDay);

    List<Statement> statements = [];

    // 1. Compute Current Unbilled Cycle Limits
    DateTime nextBillDate = DateTime(currentBillCutoff.year, currentBillCutoff.month + 1, billDay);
    DateTime nextDueDate = account.type == 'Credit' 
        ? nextBillDate.add(Duration(days: account.dueDateOffset ?? 20))
        : DateTime(nextBillDate.year, nextBillDate.month + 1, account.dueDateOffset ?? billDay);

    final unbilledTxs = accountTxs.where((t) => t.date >= currentBillCutoff.millisecondsSinceEpoch).toList();
    
    // Filter out payments (income) so they don't bloat unbilled spending totals
    final unbilledExpenses = unbilledTxs.where((t) => t.type == 'expense').toList();
    double unbilledAmount = unbilledExpenses.fold(0.0, (sum, t) => sum + (t.isInstallment ? (t.amount / (t.installmentTotal ?? 1)) : t.amount));

    statements.add(Statement(
      billingDate: nextBillDate,
      dueDate: nextDueDate,
      totalAmount: unbilledAmount,
      amountDue: unbilledAmount,
      transactions: unbilledTxs,
      label: "Current Cycle (Unbilled)",
      isBilled: false,
      isPaid: false,
    ));

    // Capture all payments made in the active unbilled timeframe to evaluate against historical dues
    final activePayments = unbilledTxs.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);

    // 2. Generate Historical Billed Cycles
    for (int i = 0; i < 12; i++) {
      DateTime billCutoff = DateTime(currentBillCutoff.year, currentBillCutoff.month - i, billDay);
      DateTime prevBillCutoff = DateTime(billCutoff.year, billCutoff.month - 1, billDay);
      
      DateTime dueDate = account.type == 'Credit'
          ? billCutoff.add(Duration(days: account.dueDateOffset ?? 20))
          : DateTime(billCutoff.year, billCutoff.month + 1, account.dueDateOffset ?? billDay);

      final periodTxs = accountTxs.where((t) => 
        t.date >= prevBillCutoff.millisecondsSinceEpoch && 
        t.date < billCutoff.millisecondsSinceEpoch
      ).toList();

      if (periodTxs.isEmpty && i > 0) continue; 

      final periodExpenses = periodTxs.where((t) => t.type == 'expense').toList();
      double totalSpend = periodExpenses.fold(0.0, (sum, t) => sum + (t.isInstallment ? (t.amount / (t.installmentTotal ?? 1)) : t.amount));
      
      double remainingDue = totalSpend;
      bool paidStatus = false;

      if (i == 0) {
        // Evaluate if the active payment due statement has been cleared by recent payments
        remainingDue = (totalSpend - activePayments).clamp(0.0, double.infinity);
        if (remainingDue <= 0 && totalSpend > 0) {
          paidStatus = true;
        }
      }

      statements.add(Statement(
        billingDate: billCutoff,
        dueDate: dueDate,
        totalAmount: totalSpend,
        amountDue: remainingDue,
        transactions: periodTxs,
        label: i == 0 ? "Payment Due" : "Statement - ${DateFormat('MMM dd, yyyy').format(billCutoff)}",
        isBilled: true,
        isPaid: paidStatus,
      ));
    }

    return statements;
  }
}