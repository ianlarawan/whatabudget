import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/models/category.dart';
import '../../utils/number_formatters.dart';

class BudgetDetailScreen extends StatelessWidget {
  final double targetAmount;
  final String frequency;
  final DateTime startDate;
  final double spentAmount;
  final List<Category> categories; // Added categories dependency
  final List<TransactionItem> transactions;

  const BudgetDetailScreen({
    super.key,
    required this.targetAmount,
    required this.frequency,
    required this.startDate,
    required this.spentAmount,
    required this.categories,
    required this.transactions,
  });

  double _calculateImpact(TransactionItem t) {
    if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) {
      return t.amount / t.installmentTotal!;
    }
    return t.amount;
  }

  Color _getCategoryColor(int index) {
    final List<Color> colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.deepPurple,
      Colors.lightGreen,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 1. Group transactions and aggregate totals by Category ID
    final Map<int, double> categorySums = {};
    for (var tx in transactions) {
      final double impact = _calculateImpact(tx);
      categorySums[tx.categoryId] = (categorySums[tx.categoryId] ?? 0.0) + impact;
    }

    int colorIdx = 0;
    final List<PieChartSectionData> chartSections = [];
    final List<Widget> legendItems = [];

    // 2. Build chart items using actual master category names and metrics
    categorySums.forEach((catId, totalValue) {
      final currentSectionColor = _getCategoryColor(colorIdx);
      
      // Dynamic master lookup translation
      final matchedCategory = categories.firstWhere(
        (c) => c.id == catId,
        orElse: () => Category(name: 'Other Expenses', icon: '💸', type: 'expense'),
      );

      chartSections.add(PieChartSectionData(
        color: currentSectionColor,
        value: totalValue,
        title: '', 
        radius: 25,
      ));

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: currentSectionColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Category Icon Display
              Text(matchedCategory.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              // Category Name Display (Groups multiple transactions into a single entry name)
              Expanded(
                child: Text(
                  matchedCategory.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₱${totalValue.toCurrency()}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );

      colorIdx++;
    });

    // 3. Append remaining unused allowance slice
    final double unspentAmount = targetAmount - spentAmount;
    if (unspentAmount > 0) {
      final Color unspentColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
      
      chartSections.add(PieChartSectionData(
        color: unspentColor,
        value: unspentAmount,
        title: '',
        radius: 25,
      ));

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: unspentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Text('🏳️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Unused Allowance',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
              Text(
                '₱${unspentAmount.toCurrency()}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Progress Breakdown'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sections: chartSections.isEmpty 
                            ? [PieChartSectionData(color: Colors.grey.shade400, value: 1, radius: 25, title: '')]
                            : chartSections,
                        centerSpaceRadius: 65,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '₱${spentAmount.toCurrency()}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Spent of ₱${targetAmount.toCurrency()}',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Distribution Guide',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: legendItems.isEmpty
                  ? const Center(child: Text('No structured transactions recorded in this cycle.'))
                  : Column(
                      children: legendItems,
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cycle History Logs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final dateStr = DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(tx.date));
              
              final txCategory = categories.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => Category(name: '', icon: '📝', type: 'expense'),
              );

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                // Prefixed the log view with the native category emoji for context
                title: Text(
                  '${txCategory.icon} ${tx.note ?? txCategory.name}', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                subtitle: Text(dateStr),
                trailing: Text(
                  '₱${_calculateImpact(tx).toCurrency()}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}