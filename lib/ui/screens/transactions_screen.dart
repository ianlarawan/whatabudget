import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../state/providers.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/models/category.dart';
import '../../utils/number_formatters.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late PageController _pageController;
  List<DateTime> _months = [];
  int _currentIndex = 0;

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Set<int> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _generateMonths(List<TransactionItem> txs) {
    if (txs.isEmpty) {
      final now = DateTime.now();
      _months = [DateTime(now.year, now.month)];
    } else {
      int minDate = txs.map((t) => t.date).reduce((a, b) => a < b ? a : b);
      DateTime start = DateTime.fromMillisecondsSinceEpoch(minDate);
      DateTime end = DateTime.now();
      
      List<DateTime> generated = [];
      DateTime current = DateTime(start.year, start.month);
      while (current.isBefore(end) || current.isAtSameMomentAs(DateTime(end.year, end.month))) {
        generated.add(current);
        current = DateTime(current.year, current.month + 1);
      }
      _months = generated;
    }
    _currentIndex = _months.length - 1;
    _pageController = PageController(initialPage: _currentIndex);
  }

  double _getDisplayAmount(TransactionItem t) {
    if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) return t.amount / t.installmentTotal!;
    return t.amount;
  }

  void _openFilterDialog(List<Category> allCats, List<TransactionItem> allTxs) {
    final availableCatIds = allTxs.map((t) => t.categoryId).toSet();
    final availableCats = allCats.where((c) => availableCatIds.contains(c.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() => _selectedCategories.clear());
                          setState(() {});
                        },
                        child: const Text('Clear All'),
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableCats.length,
                      itemBuilder: (context, i) {
                        final cat = availableCats[i];
                        final isSelected = _selectedCategories.contains(cat.id);
                        return CheckboxListTile(
                          title: Text('${cat.icon} ${cat.name}'),
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) _selectedCategories.add(cat.id!);
                              else _selectedCategories.remove(cat.id!);
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(transactionsProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search transactions...', border: InputBorder.none),
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search), 
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchCtrl.clear();
              });
            }
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: _selectedCategories.isNotEmpty ? colorScheme.primary : null), 
            onPressed: () {
              if (catsAsync.value != null && txsAsync.value != null) {
                _openFilterDialog(catsAsync.value!, txsAsync.value!);
              }
            }
          ),
        ],
      ),
      body: txsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTxs) {
          if (_months.isEmpty || allTxs.isEmpty && _months.length == 1) _generateMonths(allTxs);
          final categories = catsAsync.value ?? [];

          return Column(
            children: [
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _months.length,
                  itemBuilder: (ctx, i) {
                    bool isSelected = i == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: isSelected ? colorScheme.primary : Colors.transparent, width: 3)),
                        ),
                        child: Text(
                          DateFormat('MMMM yyyy').format(_months[i]),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemCount: _months.length,
                  itemBuilder: (ctx, idx) {
                    return _buildMonthView(_months[idx], allTxs, categories, colorScheme);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction-form'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthView(DateTime monthDate, List<TransactionItem> allTxs, List<Category> cats, ColorScheme colorScheme) {
    final nextMonth = DateTime(monthDate.year, monthDate.month + 1);
    final String query = _searchCtrl.text.toLowerCase();

    final monthTxs = allTxs.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      bool inMonth = (d.isAfter(monthDate) || d.isAtSameMomentAs(monthDate)) && d.isBefore(nextMonth);
      if (!inMonth) return false;

      if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(t.categoryId)) return false;

      if (query.isNotEmpty) {
        Category? cat;
        try { cat = cats.firstWhere((c) => c.id == t.categoryId); } catch (_) {}
        String noteMatches = t.note?.toLowerCase() ?? '';
        String catMatches = cat?.name.toLowerCase() ?? '';
        if (!noteMatches.contains(query) && !catMatches.contains(query)) return false;
      }
      return true;
    }).toList();

    monthTxs.sort((a, b) => b.date.compareTo(a.date));

    double expense = monthTxs.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + _getDisplayAmount(t));
    double income = monthTxs.where((t) => t.type == 'income').fold(0.0, (s, t) => s + _getDisplayAmount(t));
    double net = income - expense;

    Map<String, List<TransactionItem>> grouped = {};
    for (var tx in monthTxs) {
      String dayKey = DateFormat('EEEE, MMMM d').format(DateTime.fromMillisecondsSinceEpoch(tx.date));
      if (!grouped.containsKey(dayKey)) grouped[dayKey] = [];
      grouped[dayKey]!.add(tx);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('▼ ₱${expense.toCurrency()}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              Text('▲ ₱${income.toCurrency()}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                child: Text('= ₱${net.toCurrency()}', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: grouped.isEmpty
              ? const Center(child: Text('No transactions found.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: grouped.keys.length,
                  itemBuilder: (ctx, i) {
                    String day = grouped.keys.elementAt(i);
                    List<TransactionItem> dayTxs = grouped[day]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                          child: Text(day, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ...dayTxs.map((tx) {
                          Category? cat;
                          try { cat = cats.firstWhere((c) => c.id == tx.categoryId); } catch (_) {}

                          String titleText = '${cat?.icon ?? ''} ${cat?.name ?? 'Unknown'}';
                          if (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) {
                            titleText += ' ${(tx.installmentCurrent ?? 0) + 1}/${tx.installmentTotal}';
                          }

                          return ListTile(
                            onTap: () => context.push('/transaction-form', extra: tx),
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.secondaryContainer,
                              child: Text(cat?.icon ?? '?', style: TextStyle(fontSize: 20, color: colorScheme.onSecondaryContainer)),
                            ),
                            title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: tx.note != null ? Text(tx.note!) : null,
                            trailing: Text(
                              '${tx.type == 'expense' ? '-' : '+'}₱${_getDisplayAmount(tx).toCurrency()}}',
                              style: TextStyle(
                                color: tx.type == 'expense' ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}