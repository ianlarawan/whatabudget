import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../../state/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/models/account.dart';
import '../../services/interest_service.dart';
import '../../utils/number_formatters.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  double? _budgetAmount;
  String? _budgetFreq;
  DateTime? _budgetStart;

  // Helper: Filter for active spending only
bool _isBudgetTransaction(TransactionItem t, List<Category> categories) {
    if (t.type != 'expense') return false;
    
    final cat = categories.firstWhere(
      (c) => c.id == t.categoryId, 
      orElse: () => Category(name: '', icon: '', type: '')
    );
    
    // Added 'Credit/Loan Bill Payment' to prevent double deduction
    final excludedCategories = [
      'Balance Adjustment', 
      'Transfer Fee', 
      'Interest Charges', 
      'Credit/Loan Bill Payment'
    ];
    if (excludedCategories.contains(cat.name)) return false;
    if (t.note != null && t.note!.contains('Initial Balance')) return false;

    return true;
  }

  // Helper: Calculate Due Date Countdown based on nearest deadline
  String? _getDueDateCountdown(Account acc) {
  if (!['Credit', 'Loans'].contains(acc.type) || acc.billingDate == null) return null;

  final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime targetDue;

  if (acc.type == 'Credit') {
    // Credit Logic: Billing Date + Offset days
    final int billDay = acc.billingDate!;
    final int offset = acc.dueDateOffset ?? 20;
    
    DateTime pDue = DateTime(now.year, now.month - 1, billDay).add(Duration(days: offset));
    DateTime cDue = DateTime(now.year, now.month, billDay).add(Duration(days: offset));
    DateTime nDue = DateTime(now.year, now.month + 1, billDay).add(Duration(days: offset));

    if (!pDue.isBefore(now)) targetDue = pDue;
    else if (!cDue.isBefore(now)) targetDue = cDue;
    else targetDue = nDue;
  } else {
    // Loan Logic: dueDateOffset is the actual day of the month (e.g., 05)
    final int dueDay = acc.dueDateOffset ?? acc.billingDate!;
    
    DateTime pDue = DateTime(now.year, now.month - 1, dueDay);
    DateTime cDue = DateTime(now.year, now.month, dueDay);
    DateTime nDue = DateTime(now.year, now.month + 1, dueDay);

    // If Today is May 4 and cDue is May 5, it correctly picks May 5
    if (!pDue.isBefore(now)) targetDue = pDue;
    else if (!cDue.isBefore(now)) targetDue = cDue;
    else targetDue = nDue;
  }

  final daysLeft = targetDue.difference(now).inDays;

  if (daysLeft == 0) return 'due today';
  if (daysLeft == 1) return 'due tomorrow';
  if (daysLeft < 0) return 'overdue';
  return 'due in $daysLeft days';
}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InterestService.processPendingInterest(ref);
      _loadBudget();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      InterestService.processPendingInterest(ref);
    }
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _budgetAmount = prefs.getDouble('budget_amount');
      _budgetFreq = prefs.getString('budget_frequency');
      int? startMs = prefs.getInt('budget_start_date');
      if (startMs != null) _budgetStart = DateTime.fromMillisecondsSinceEpoch(startMs);
    });
  }

  Future<void> _handleRefresh() async {
    await InterestService.processPendingInterest(ref);
    await _loadBudget();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  DateTime _calculateNext(DateTime current, String freq) {
    if (freq == 'Daily') return current.add(const Duration(days: 1));
    if (freq == 'Weekly') return current.add(const Duration(days: 7));
    if (freq == 'Bi-Weekly') return current.add(const Duration(days: 14));
    if (freq == 'Monthly') return DateTime(current.year, current.month + 1, current.day);
    if (freq == 'Yearly') return DateTime(current.year + 1, current.month, current.day);
    return current.add(const Duration(days: 30));
  }

  double _calculateImpact(TransactionItem t) {
    if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) return t.amount / t.installmentTotal!;
    return t.amount;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final accounts = accountsAsync.value ?? [];
    double netWorth = 0;
    for (var acc in accounts) {
      if (!acc.includeInNetWorth) continue;
      if (['Credit', 'Loans'].contains(acc.type)) {
        netWorth -= acc.balance;
      } else {
        netWorth += acc.balance;
      }
    }

    final transactions = transactionsAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
          IconButton(icon: const Icon(Icons.account_balance_wallet), onPressed: () => context.push('/add-account')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _buildSummaryCard(netWorth, accounts, colorScheme),
            const Divider(),
            
            accountsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (accountsData) {
                if (accountsData.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No accounts configured.')));
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 1.25, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: accountsData.length,
                  itemBuilder: (context, index) {
                    final acc = accountsData[index];
                    final countdown = _getDueDateCountdown(acc);
                    final bool isDebt = ['Credit', 'Loans'].contains(acc.type);
                    String balanceLabel = isDebt ? "Total Owed" : "Balance";

                    return InkWell(
                      onTap: () => context.push('/account/${acc.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(acc.icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      acc.name, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${acc.provider} • ${acc.type}', 
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (countdown != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    countdown,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: countdown.contains('overdue') ? Colors.red : Colors.orange,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                balanceLabel,
                                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '₱${acc.balance.toCurrency()}', 
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w900,
                                  color: isDebt ? Colors.red : Colors.green
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            
            const Divider(),
            _buildBudgetSection(transactions, categories, colorScheme),
            const Divider(),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(onPressed: () => context.push('/transactions'), child: const Text('View All')),
                ],
              ),
            ),
            
            transactionsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
              data: (transactionsData) {
                if (transactionsData.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No transactions recorded.')));
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactionsData.take(5).length,
                  itemBuilder: (context, index) {
                    final tx = transactionsData[index];
                    final dateStr = DateFormat('MMM dd, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(tx.date));
                    
                    Category? cat;
                    try { cat = categories.firstWhere((c) => c.id == tx.categoryId); } catch (_) {}

                    String titleText = '${cat?.icon ?? ''} ${cat?.name ?? 'Unknown'}';
                    if (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) {
                      titleText += ' ${(tx.installmentCurrent ?? 0) + 1}/${tx.installmentTotal}';
                    }

                    return ListTile(
                      onTap: () => context.push('/transaction-form', extra: tx),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (tx.note != null && tx.note!.isNotEmpty) Text(tx.note!, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      subtitle: Text('${tx.type.toUpperCase()} • $dateStr'),
                      trailing: Text(
                        '₱${_calculateImpact(tx).toCurrency()}', 
                        style: TextStyle(color: tx.type == 'income' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await context.push('/transaction-form');
            if (mounted) _handleRefresh(); 
          },
          child: const Icon(Icons.add),
        ),
    );
  }

  Widget _buildSummaryCard(double netWorth, List<Account> accounts, ColorScheme colorScheme) {
    double liquidAssets = accounts
        .where((a) => !['Credit', 'Loans'].contains(a.type))
        .fold(0, (sum, a) => sum + a.balance);

    double totalDebt = accounts
        .where((a) => ['Credit', 'Loans'].contains(a.type))
        .fold(0, (sum, a) => sum + a.balance);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text('Total Net Worth', style: TextStyle(fontSize: 16)),
          Text(
            '₱${netWorth.toCurrency()}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: netWorth < 0 ? Colors.red : colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('Liquid Assets', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  Text('₱${liquidAssets.toCurrency()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              Container(height: 30, width: 1, color: colorScheme.outlineVariant),
              Column(
                children: [
                  Text('Total Debt', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  Text('₱${totalDebt.toCurrency()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSection(List<TransactionItem> allTxs, List<Category> categories, ColorScheme colorScheme) {
    if (_budgetAmount == null || _budgetFreq == null || _budgetStart == null) return const SizedBox.shrink();

    DateTime now = DateTime.now();
    DateTime pStart = _budgetStart!;
    DateTime pEnd = pStart;

    if (now.isBefore(pStart)) {
      pEnd = _calculateNext(pStart, _budgetFreq!);
    } else {
      while (true) {
        pEnd = _calculateNext(pStart, _budgetFreq!);
        if (now.isBefore(pEnd)) break;
        pStart = pEnd;
      }
    }

    double actualSpent = allTxs
        .where((t) => 
            t.date >= pStart.millisecondsSinceEpoch && 
            t.date < pEnd.millisecondsSinceEpoch &&
            _isBudgetTransaction(t, categories))
        .fold(0.0, (s, t) => s + _calculateImpact(t));

    double left = _budgetAmount! - actualSpent;
    double progress = actualSpent / _budgetAmount!;
    int daysLeft = max(1, pEnd.difference(now).inDays);
    double dailyAllowable = left > 0 ? left / daysLeft : 0;
    bool isOverBudget = actualSpent > _budgetAmount!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Budget Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            // Inside dashboard_screen.dart -> _buildBudgetSection -> InkWell -> onTap:
            onTap: () async {
              await context.push('/budget-details', extra: {
                'amount': _budgetAmount,
                'freq': _budgetFreq,
                'start': _budgetStart,
                'spent': actualSpent,
                'categories': categories, // ADD THIS LINE HERE
                'transactions': allTxs.where((t) => 
                  t.date >= pStart.millisecondsSinceEpoch && 
                  t.date < pEnd.millisecondsSinceEpoch && 
                  _isBudgetTransaction(t, categories)).toList(),
              });
              if (mounted) _loadBudget();
            },
            child: Card(
              color: isOverBudget ? colorScheme.errorContainer : colorScheme.surfaceContainerHighest,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: isOverBudget ? colorScheme.error : colorScheme.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Current Budget ($_budgetFreq)', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('₱${left.clamp(0.0, double.infinity).toCurrency()} left of ₱${_budgetAmount!.toCurrency()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(5)),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(color: isOverBudget ? colorScheme.error : colorScheme.primary, borderRadius: BorderRadius.circular(5)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM dd').format(pStart), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        Text('${(progress * 100).toStringAsFixed(0)}% Spent', style: TextStyle(fontSize: 12, color: isOverBudget ? colorScheme.error : colorScheme.primary, fontWeight: FontWeight.bold)),
                        Text(DateFormat('MMM dd').format(pEnd.subtract(const Duration(days: 1))), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isOverBudget 
                        ? 'You have exceeded your budget by ₱${(actualSpent - _budgetAmount!).toCurrency()}.'
                        : 'You can spend ₱${dailyAllowable.toCurrency()}/day for $daysLeft more day(s).',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}