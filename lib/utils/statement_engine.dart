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

    // 1. Calculate Lifetime Payments (Income) to execute a waterfall ledger deduction
    double lifetimePayments = 0.0;
    for (var tx in accountTxs) {
      if (tx.type == 'income') {
        lifetimePayments += tx.amount;
      }
    }

    List<Statement> statements = [];

    // 2. Build Historical Cycles (Iterating Oldest to Newest)
    for (int i = 12; i >= 0; i--) {
      DateTime billCutoff = DateTime(currentBillCutoff.year, currentBillCutoff.month - i, billDay);
      DateTime prevBillCutoff = DateTime(billCutoff.year, billCutoff.month - 1, billDay);
      
      DateTime dueDate = account.type == 'Credit'
          ? billCutoff.add(Duration(days: account.dueDateOffset ?? 20))
          : DateTime(billCutoff.year, billCutoff.month + 1, account.dueDateOffset ?? billDay);

      final periodTxs = accountTxs.where((t) => 
        t.date >= prevBillCutoff.millisecondsSinceEpoch && 
        t.date < billCutoff.millisecondsSinceEpoch
      ).toList();

      double periodSpend = 0.0;
      for (var tx in periodTxs) {
        if (tx.type == 'expense') {
          periodSpend += (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) 
              ? tx.amount / tx.installmentTotal! 
              : tx.amount;
        }
      }
      
      // Cascade payments against the oldest statement first
      double amountDue = periodSpend;
      if (lifetimePayments >= periodSpend) {
        lifetimePayments -= periodSpend;
        amountDue = 0.0;
      } else {
        amountDue -= lifetimePayments;
        lifetimePayments = 0.0;
      }

      if (periodTxs.isNotEmpty || i == 0) {
        statements.insert(0, Statement(
          billingDate: billCutoff,
          dueDate: dueDate,
          totalAmount: periodSpend,
          amountDue: amountDue,
          transactions: periodTxs,
          label: i == 0 ? "Payment Due" : "Statement - ${DateFormat('MMM dd, yyyy').format(billCutoff)}",
          isBilled: true,
          isPaid: amountDue <= 0 && periodSpend > 0,
        ));
      }
    }

    // 3. Current Unbilled Cycle (Enforcing strict upper boundary constraints)
    DateTime nextBillDate = DateTime(currentBillCutoff.year, currentBillCutoff.month + 1, billDay);
    DateTime nextDueDate = account.type == 'Credit' 
        ? nextBillDate.add(Duration(days: account.dueDateOffset ?? 20))
        : DateTime(nextBillDate.year, nextBillDate.month + 1, account.dueDateOffset ?? billDay);

    final unbilledTxs = accountTxs.where((t) => 
      t.date >= currentBillCutoff.millisecondsSinceEpoch &&
      t.date < nextBillDate.millisecondsSinceEpoch 
    ).toList();
    
    double unbilledSpend = 0.0;
    for (var tx in unbilledTxs) {
      if (tx.type == 'expense') {
        unbilledSpend += (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) 
            ? tx.amount / tx.installmentTotal! 
            : tx.amount;
      }
    }

    double unbilledDue = unbilledSpend;
    if (lifetimePayments > 0) {
      unbilledDue -= lifetimePayments;
    }

    statements.insert(0, Statement(
      billingDate: nextBillDate,
      dueDate: nextDueDate,
      totalAmount: unbilledSpend, 
      amountDue: unbilledDue,
      transactions: unbilledTxs,
      label: "Current Cycle (Unbilled)",
      isBilled: false,
      isPaid: false,
    ));

    return statements;
  }
}