import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../state/providers.dart';
import '../../domain/models/transaction_item.dart';
import '../../utils/number_formatters.dart';

class AllSpendingScreen extends ConsumerStatefulWidget {
  const AllSpendingScreen({super.key});
  @override
  ConsumerState<AllSpendingScreen> createState() => _AllSpendingScreenState();
}

class _AllSpendingScreenState extends ConsumerState<AllSpendingScreen> {
  int _tabIndex = 0; 
  String _historyRange = '6 months';

  double _calculateImpact(TransactionItem t) {
    if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) return t.amount / t.installmentTotal!;
    return t.amount;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Spending'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0 ? colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_tabIndex == 0) Icon(Icons.check, size: 16, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 4),
                            Text('Current', style: TextStyle(
                              fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _tabIndex == 0 ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _tabIndex == 1 ? colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_tabIndex == 1) Icon(Icons.check, size: 16, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 4),
                            Text('History', style: TextStyle(
                              fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _tabIndex == 1 ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (ctx, ref, child) {
                final txsAsync = ref.watch(transactionsProvider);
                return txsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (txs) {
                    final filteredTxs = txs.where((t) => 
                      t.note != 'Initial Balance' && 
                      t.note != 'Balance Adjustment' && 
                      !(t.note?.startsWith('Transfer') ?? false)
                    ).toList();

                    if (_tabIndex == 0) return _buildCurrentView(filteredTxs, colorScheme);
                    return _buildHistoryView(filteredTxs, colorScheme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView(List<TransactionItem> txs, ColorScheme colorScheme) {
    double exp = txs.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + _calculateImpact(t));
    double inc = txs.where((t) => t.type == 'income').fold(0.0, (s, t) => s + _calculateImpact(t));
    double net = inc - exp;
    int expCount = txs.where((t) => t.type == 'expense').length;
    int incCount = txs.where((t) => t.type == 'income').length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: const [
              Icon(Icons.pie_chart, size: 16),
              SizedBox(width: 8),
              Text('All Time', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('Net Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₱${net.toCurrency()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${txs.length} transactions', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildProgressRow('Expense', expCount, exp, Colors.red, exp / (exp + inc == 0 ? 1 : exp + inc), colorScheme),
                const SizedBox(height: 12),
                _buildProgressRow('Income', incCount, inc, Colors.green, inc / (exp + inc == 0 ? 1 : exp + inc), colorScheme),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: DonutChartPainter(exp: exp, inc: inc),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(String label, int count, double amount, Color color, double ratio, ColorScheme colorScheme) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(' (x$count)', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(height: 4, color: colorScheme.surfaceContainerHighest),
              FractionallySizedBox(
                widthFactor: ratio.isNaN ? 0 : ratio,
                child: Container(height: 4, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('₱${amount.toCurrency()}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHistoryView(List<TransactionItem> txs, ColorScheme colorScheme) {
    int dataPoints = 6;
    if (_historyRange == '1 month') dataPoints = 4;
    else if (_historyRange == '1 year') dataPoints = 12;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DropdownButtonFormField<String>(
            value: _historyRange,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.history),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: '1 month', child: Text('1 month')),
              DropdownMenuItem(value: '6 months', child: Text('6 months')),
              DropdownMenuItem(value: '1 year', child: Text('1 year')),
            ],
            onChanged: (v) => setState(() => _historyRange = v!),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: LineGraphPainter(txs: txs, range: _historyRange, colorScheme: colorScheme),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dataPoints,
            itemBuilder: (ctx, i) {
              DateTime now = DateTime.now();
              DateTime start, end;
              String label;

              if (_historyRange == '1 month') {
                end = now.subtract(Duration(days: i * 7));
                start = now.subtract(Duration(days: (i + 1) * 7));
                label = 'Week of ${DateFormat('MMM d').format(start)}';
              } else {
                start = DateTime(now.year, now.month - i, 1);
                end = DateTime(now.year, now.month - i + 1, 1);
                label = i == 0 ? 'Current Month' : DateFormat('MMMM yyyy').format(start);
              }
              
              final periodTxs = txs.where((t) => t.date >= start.millisecondsSinceEpoch && t.date < end.millisecondsSinceEpoch);
              double pExp = periodTxs.where((t) => t.type == 'expense').fold(0, (s,t) => s + _calculateImpact(t));
              double pInc = periodTxs.where((t) => t.type == 'income').fold(0, (s,t) => s + _calculateImpact(t));
              
              return Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('₱${(pInc - pExp).toCurrency()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('▼ ₱${pExp.toCurrency()}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                          Text('▲ ₱${pInc.toCurrency()}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double exp;
  final double inc;

  DonutChartPainter({required this.exp, required this.inc});

  @override
  void paint(Canvas canvas, Size size) {
    double total = exp + inc;
    if (total == 0) return;

    Paint paintExp = Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 30;
    Paint paintInc = Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 30;

    double expAngle = (exp / total) * 2 * pi;
    double incAngle = (inc / total) * 2 * pi;
    
    Rect rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.height, height: size.height);

    canvas.drawArc(rect, -pi / 2, expAngle, false, paintExp);
    canvas.drawArc(rect, -pi / 2 + expAngle, incAngle, false, paintInc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineGraphPainter extends CustomPainter {
  final List<TransactionItem> txs;
  final String range;
  final ColorScheme colorScheme;

  LineGraphPainter({required this.txs, required this.range, required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    Paint linePaint = Paint()..color = colorScheme.primary..strokeWidth = 2..style = PaintingStyle.stroke;
    Paint gridPaint = Paint()..color = colorScheme.surfaceContainerHighest..strokeWidth = 1;
    
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), gridPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gridPaint);
    
    if (txs.isEmpty) return;

    Path path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.8, size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.2);
    
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}