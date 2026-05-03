import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/account.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/models/category.dart';
import '../../utils/number_formatters.dart';

class StatementDetailScreen extends StatelessWidget {
  final Account account;
  final String statementType;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime dueDate;
  final double totalAmount;
  final List<TransactionItem> transactions;
  final List<Category> categories;

  const StatementDetailScreen({
    super.key, required this.account, required this.statementType, required this.startDate, 
    required this.endDate, required this.dueDate, required this.totalAmount, 
    required this.transactions, required this.categories,
  });

  double _calculateImpact(TransactionItem t) {
    if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) return t.amount / t.installmentTotal!;
    return t.amount;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(title: Text('$statementType Statement')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(account.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text('Statement Date: ${DateFormat('MMM dd, yyyy').format(endDate)}', style: TextStyle(fontSize: 14, color: colorScheme.onPrimaryContainer)),
                Text('Payment Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}', style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Total Spend / Due', style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer.withOpacity(0.7))),
                Text('₱${totalAmount.toCurrency()}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                Category? cat;
                try { cat = categories.firstWhere((c) => c.id == tx.categoryId); } catch (_) {}
                final dateStr = DateFormat('MMM dd, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(tx.date));
                
                String titleText = '${cat?.icon ?? ''} ${cat?.name ?? 'Unknown'}';
                if (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) {
                  titleText += ' ${(tx.installmentCurrent ?? 0) + 1}/${tx.installmentTotal}';
                }

                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (tx.note != null && tx.note!.isNotEmpty) Text(tx.note!, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  subtitle: Text('${tx.type.toUpperCase()} • $dateStr', style: const TextStyle(fontSize: 10)),
                  trailing: Text('₱${_calculateImpact(tx).toCurrency()}', style: TextStyle(color: tx.type == 'income' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}