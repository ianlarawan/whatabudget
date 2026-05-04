import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../domain/models/transaction_item.dart';
import '../../utils/number_formatters.dart';
import 'package:go_router/go_router.dart';

class BudgetDetailScreen extends StatelessWidget {
  final double targetAmount;
  final String frequency;
  final DateTime startDate;
  final double spentAmount;
  final List<TransactionItem> transactions;

  const BudgetDetailScreen({
    super.key,
    required this.targetAmount,
    required this.frequency,
    required this.startDate,
    required this.spentAmount,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double leftAmount = targetAmount - spentAmount;
    final double percentageSpent = (spentAmount / targetAmount).clamp(0.0, 1.0);
    final bool isOverBudget = spentAmount > targetAmount;

    return Scaffold(
      // Locate your AppBar actions and modify the onPressed function:
      appBar: AppBar(
        title: const Text('Budget Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // Wait for the Edit screen to pop
              final bool? changesMade = await context.push<bool>('/edit-budget', extra: {
                'amount': targetAmount,
                'freq': frequency,
                'start': startDate,
              });

              // If changes were made, immediately pop this screen to return to the dashboard
              if (changesMade == true && context.mounted) {
                context.pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Segment
              Text(
                '₱${leftAmount.clamp(0.0, double.infinity).toCurrency()} left of ₱${targetAmount.toCurrency()}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: percentageSpent,
                minHeight: 12,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: isOverBudget ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Current $frequency Cycle',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 32),

              // Donut Chart Segment
              if (transactions.isNotEmpty) ...[
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: _generateChartSections(colorScheme),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              const Text('Transactions this cycle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),

              // Transaction List
              if (transactions.isEmpty)
                const Center(child: Text('No spending this cycle.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final dateStr = DateFormat('MMM dd').format(DateTime.fromMillisecondsSinceEpoch(tx.date));
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.receipt_long, color: colorScheme.primary),
                      ),
                      title: Text(tx.note?.isNotEmpty == true ? tx.note! : 'Expense'),
                      subtitle: Text(dateStr),
                      trailing: Text(
                        '-₱${tx.amount.toCurrency()}',
                        style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _generateChartSections(ColorScheme colorScheme) {
    // In a real scenario, you'd group transactions by Category ID here.
    // For now, we visualize the chunks of individual transactions.
    final List<Color> colors = [Colors.blue, Colors.pink, Colors.orange, Colors.green, Colors.purple];
    
    return transactions.asMap().entries.map((entry) {
      final index = entry.key;
      final tx = entry.value;
      
      return PieChartSectionData(
        value: tx.amount,
        color: colors[index % colors.length],
        showTitle: false,
        radius: 40,
      );
    }).toList();
  }
}