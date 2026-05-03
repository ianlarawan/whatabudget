import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../state/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/transaction_item.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Set<int> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _calculateImpact(TransactionItem t) {
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
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search transactions...', border: InputBorder.none),
              )
            : const Text('All Transactions'),
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
            icon: Icon(Icons.filter_list, color: _selectedCategories.isNotEmpty ? Colors.blue : null), 
            onPressed: () {
              if (categoriesAsync.value != null && transactionsAsync.value != null) {
                _openFilterDialog(categoriesAsync.value!, transactionsAsync.value!);
              }
            }
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          if (transactions.isEmpty) return const Center(child: Text('No transactions recorded.'));
          final categories = categoriesAsync.value ?? [];
          final String query = _searchCtrl.text.toLowerCase();

          final filteredTxs = transactions.where((t) {
            if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(t.categoryId)) return false;
            
            if (query.isNotEmpty) {
              Category? cat;
              try { cat = categories.firstWhere((c) => c.id == t.categoryId); } catch (_) {}
              String noteMatches = t.note?.toLowerCase() ?? '';
              String catMatches = cat?.name.toLowerCase() ?? '';
              if (!noteMatches.contains(query) && !catMatches.contains(query)) return false;
            }
            return true;
          }).toList();

          if (filteredTxs.isEmpty) return const Center(child: Text('No transactions match criteria.'));

          return ListView.builder(
            itemCount: filteredTxs.length,
            itemBuilder: (context, index) {
              final tx = filteredTxs[index];
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
                  '₱${_calculateImpact(tx).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: tx.type == 'income' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}