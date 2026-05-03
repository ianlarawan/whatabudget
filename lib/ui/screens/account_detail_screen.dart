import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../state/providers.dart';
import '../../domain/models/account.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/models/category.dart';
import '../../domain/models/interest_tier.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final int accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _isEditing = false;
  bool _isInitialized = false;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _providerCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _balanceCtrl;
  late TextEditingController _iconCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _adbCtrl;
  late String _networkSelection;
  late TextEditingController _limitCtrl;
  late TextEditingController _cashAdvanceCtrl;
  late TextEditingController _billingCtrl;
  late TextEditingController _dueCtrl;
  bool _includeNetWorth = true;

  late String _interestFrequency;
  late List<InterestTier> _tiers;
  final _tierThresholdCtrl = TextEditingController();
  final _tierRateCtrl = TextEditingController();

  final List<String> _networks = ['Amex', 'Diners Club', 'JCB', 'Mastercard', 'UnionPay', 'Visa'];

  @override
  void dispose() {
    if (_isInitialized) {
      _providerCtrl.dispose(); _nameCtrl.dispose(); _balanceCtrl.dispose(); _iconCtrl.dispose(); 
      _goalCtrl.dispose(); _adbCtrl.dispose(); _limitCtrl.dispose(); _cashAdvanceCtrl.dispose(); 
      _billingCtrl.dispose(); _dueCtrl.dispose(); _tierThresholdCtrl.dispose(); _tierRateCtrl.dispose();
    }
    super.dispose();
  }

  void _initControllers(Account acc) {
    _providerCtrl = TextEditingController(text: acc.provider);
    _nameCtrl = TextEditingController(text: acc.name);
    _balanceCtrl = TextEditingController(text: acc.balance.toString());
    _iconCtrl = TextEditingController(text: acc.icon);
    _goalCtrl = TextEditingController(text: acc.goalBalance?.toString() ?? '');
    _adbCtrl = TextEditingController(text: acc.interestRate?.toString() ?? '');
    _networkSelection = _networks.contains(acc.cardNetwork) ? acc.cardNetwork! : 'Mastercard';
    _limitCtrl = TextEditingController(text: acc.creditLimit?.toString() ?? '');
    _cashAdvanceCtrl = TextEditingController(text: acc.cashAdvanceLimit?.toString() ?? '');
    _billingCtrl = TextEditingController(text: acc.billingDate?.toString() ?? '');
    _dueCtrl = TextEditingController(text: acc.dueDateOffset?.toString() ?? '');
    _includeNetWorth = acc.includeInNetWorth;
    
    _interestFrequency = acc.interestFrequency;
    _tiers = List.from(acc.interestTiers);
    
    _isInitialized = true;
  }

  void _addTier() {
    double? threshold = double.tryParse(_tierThresholdCtrl.text);
    double? rate = double.tryParse(_tierRateCtrl.text);
    if (threshold != null && rate != null) {
      setState(() {
        _tiers.add(InterestTier(threshold: threshold, rate: rate));
        _tiers.sort((a, b) => a.threshold.compareTo(b.threshold));
        _tierThresholdCtrl.clear(); _tierRateCtrl.clear();
      });
    }
  }

  void _saveAccount(Account oldAcc) {
    if (!_formKey.currentState!.validate()) return;
    if (_interestFrequency == 'monthly_adb' && _adbCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current ADB is required.')));
      return;
    }

    final updated = Account(
      id: oldAcc.id, type: oldAcc.type, provider: _providerCtrl.text,
      name: _nameCtrl.text, icon: _iconCtrl.text.isEmpty ? '🏦' : _iconCtrl.text,
      balance: double.tryParse(_balanceCtrl.text) ?? 0,
      includeInNetWorth: _includeNetWorth,
      goalBalance: double.tryParse(_goalCtrl.text),
      interestRate: oldAcc.type == 'Savings' ? double.tryParse(_adbCtrl.text) : oldAcc.interestRate,
      cardNetwork: oldAcc.type == 'Credit' ? _networkSelection : null,
      creditLimit: double.tryParse(_limitCtrl.text),
      cashAdvanceLimit: double.tryParse(_cashAdvanceCtrl.text),
      billingDate: int.tryParse(_billingCtrl.text),
      dueDateOffset: int.tryParse(_dueCtrl.text),
      interestFrequency: oldAcc.type == 'Savings' ? _interestFrequency : oldAcc.interestFrequency,
      interestTiers: oldAcc.type == 'Savings' ? _tiers : oldAcc.interestTiers,
      accumulatedInterest: oldAcc.accumulatedInterest,
      lastInterestDate: oldAcc.lastInterestDate,
    );
    ref.read(accountsProvider.notifier).updateAccount(updated, oldBalance: oldAcc.balance);
    setState(() => _isEditing = false);
  }

  double _calculateImpact(TransactionItem t) {
    if (t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0) return t.amount / t.installmentTotal!;
    return t.amount;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final txsAsync = ref.watch(transactionsProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return accountsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (accounts) {
        final acc = accounts.firstWhere((a) => a.id == widget.accountId, orElse: () => Account(type: 'Unknown', provider: '', name: 'Not Found', balance: 0));
        if (acc.id == null) return const Scaffold(body: Center(child: Text('Account deleted')));
        
        if (!_isInitialized) _initControllers(acc);

        final txs = txsAsync.value?.where((t) => t.accountId == acc.id).toList() ?? [];
        final cats = catsAsync.value ?? [];
        final isDebt = ['Credit', 'Loans'].contains(acc.type);

        return Scaffold(
          appBar: AppBar(
            title: Text(acc.name),
            actions: [
              IconButton(
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                onPressed: () {
                  if (_isEditing) _saveAccount(acc);
                  else setState(() => _isEditing = true);
                },
              )
            ],
          ),
          body: isDebt ? _buildCreditView(acc, txs, cats, colorScheme) : _buildSavingsView(acc, txs, cats, colorScheme),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
              icon: const Icon(Icons.delete),
              label: const Text('Delete Account'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text('Are you sure you want to delete this account? All associated transactions and history will be permanently erased. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
                        onPressed: () {
                          ref.read(accountsProvider.notifier).deleteAccount(acc.id!);
                          Navigator.pop(ctx); context.pop(); 
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  )
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavingsView(Account acc, List<TransactionItem> txs, List<Category> cats, ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 60, child: _buildField(_iconCtrl, 'Icon', enabled: _isEditing, colorScheme: colorScheme)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildField(_nameCtrl, 'Account Name', enabled: _isEditing, colorScheme: colorScheme)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildField(_balanceCtrl, 'Current Balance (₱)', isNum: true, enabled: _isEditing, colorScheme: colorScheme)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildField(_providerCtrl, 'Provider / Bank', enabled: _isEditing, colorScheme: colorScheme)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildField(_goalCtrl, 'Goal Amount (₱)', isNum: true, enabled: _isEditing, colorScheme: colorScheme)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Net Worth', style: TextStyle(fontSize: 12)),
                          value: _isEditing ? _includeNetWorth : acc.includeInNetWorth,
                          onChanged: _isEditing ? (val) => setState(() => _includeNetWorth = val) : null,
                        ),
                      ),
                    ],
                  ),
                  if (acc.type == 'Savings') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: colorScheme.primary.withOpacity(0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Automated Interest Engine', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                          if (_isEditing)
                            DropdownButtonFormField<String>(
                              value: _interestFrequency,
                              decoration: const InputDecoration(labelText: 'Crediting Frequency', isDense: true),
                              items: const [
                                DropdownMenuItem(value: 'none', child: Text('None (Manual)')),
                                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                DropdownMenuItem(value: 'monthly_adb', child: Text('Monthly (ADB)')),
                              ],
                              onChanged: (val) => setState(() => _interestFrequency = val!),
                            )
                          else
                            _buildStaticField('Crediting Frequency', _interestFrequency.toUpperCase().replaceAll('_', ' '), colorScheme),
                          
                          if (_interestFrequency == 'monthly_adb')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _isEditing 
                                ? _buildField(_adbCtrl, 'Current ADB (₱)', isNum: true, enabled: true, colorScheme: colorScheme)
                                : _buildStaticField('Current ADB', '₱${acc.interestRate?.toStringAsFixed(2) ?? "0.00"}', colorScheme),
                            ),

                          const SizedBox(height: 16),
                          const Text('Interest Tiers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (_isEditing)
                            Row(
                              children: [
                                Expanded(child: _buildField(_tierThresholdCtrl, 'Balance Above (₱)', isNum: true, enabled: true, colorScheme: colorScheme)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildField(_tierRateCtrl, 'Rate (% p.a.)', isNum: true, enabled: true, colorScheme: colorScheme)),
                                IconButton(icon: Icon(Icons.add_circle, color: colorScheme.primary), onPressed: _addTier),
                              ],
                            ),
                          if (_tiers.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _tiers.length,
                              itemBuilder: (ctx, i) => ListTile(
                                dense: true, contentPadding: EdgeInsets.zero,
                                title: Text('> ₱${_tiers[i].threshold.toStringAsFixed(2)}'),
                                subtitle: Text('${_tiers[i].rate}% p.a.'),
                                trailing: _isEditing ? IconButton(icon: Icon(Icons.delete, color: colorScheme.error, size: 20), onPressed: () => setState(() => _tiers.removeAt(i))) : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (!_isEditing && acc.goalBalance != null && acc.goalBalance! > 0) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: (acc.balance / acc.goalBalance!).clamp(0.0, 1.0), minHeight: 6),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${((acc.balance / acc.goalBalance!) * 100).toStringAsFixed(1)}% Saved', style: const TextStyle(fontSize: 12)),
                        Text('₱${(acc.goalBalance! - acc.balance).clamp(0.0, double.infinity).toStringAsFixed(2)} Left', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider()),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          _buildTransactionSliverList(txs, cats),
        ],
      ),
    );
  }

  Widget _buildCreditView(Account acc, List<TransactionItem> txs, List<Category> cats, ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 60, child: _buildField(_iconCtrl, 'Icon', enabled: _isEditing, colorScheme: colorScheme)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField(_nameCtrl, 'Account Name', enabled: _isEditing, colorScheme: colorScheme)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField(_balanceCtrl, 'Balance (₱)', isNum: true, enabled: _isEditing, colorScheme: colorScheme)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField(_providerCtrl, 'Provider / Bank', enabled: _isEditing, colorScheme: colorScheme)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField(_limitCtrl, 'Credit Limit', isNum: true, enabled: _isEditing, colorScheme: colorScheme)),
                        const SizedBox(width: 8),
                        if (acc.type == 'Credit') 
                          Expanded(
                            child: _isEditing 
                              ? DropdownButtonFormField<String>(
                                  value: _networkSelection,
                                  decoration: const InputDecoration(labelText: 'Network', isDense: true),
                                  items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                  onChanged: (val) => setState(() => _networkSelection = val!),
                                )
                              : _buildStaticField('Network', acc.cardNetwork ?? 'N/A', colorScheme)
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField(_billingCtrl, 'Billing Day', isNum: true, enabled: _isEditing, colorScheme: colorScheme)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField(_dueCtrl, acc.type == 'Credit' ? 'Due Offset' : 'Due Day', isNum: true, enabled: _isEditing, colorScheme: colorScheme)),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Net Worth', style: TextStyle(fontSize: 10)),
                            value: _isEditing ? _includeNetWorth : acc.includeInNetWorth,
                            onChanged: _isEditing ? (val) => setState(() => _includeNetWorth = val) : null,
                          ),
                        ),
                      ],
                    ),
                    if (!_isEditing && acc.creditLimit != null)
                      Builder(
                        builder: (ctx) {
                          double unbilled = 0;
                          for (var t in txs.where((t) => t.isInstallment && t.installmentTotal != null && t.installmentTotal! > 0)) {
                            double monthly = t.amount / t.installmentTotal!;
                            int billed = (t.installmentCurrent ?? 0) + 1;
                            double remaining = t.amount - (monthly * billed);
                            if (remaining > 0) unbilled += remaining;
                          }
                          double available = acc.creditLimit! - acc.balance - unbilled;
                          return Align(
                            alignment: Alignment.centerLeft, 
                            child: Text('Available Credit: ₱${available.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12))
                          );
                        }
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: TabBar(tabs: [Tab(text: 'Current'), Tab(text: 'Installments'), Tab(text: 'Paid')]),
            ),
          ],
          body: TabBarView(
            children: [
              _buildBillingDashboard(acc, txs, cats),
              _buildInstallmentsDashboard(txs, cats),
              CustomScrollView(slivers: [_buildTransactionSliverList(txs.where((t) => t.type == 'income').toList(), cats)]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingDashboard(Account acc, List<TransactionItem> txs, List<Category> cats) {
    final now = DateTime.now();
    final billDay = acc.billingDate ?? 1;
    final dueDayOrOffset = acc.dueDateOffset ?? 0;
    
    DateTime currentBillEnd = DateTime(now.year, now.month, billDay);
    DateTime previousBillEnd = DateTime(now.year, now.month - 1, billDay);
    DateTime previousBillStart = DateTime(now.year, now.month - 2, billDay);
    
    DateTime currentDueDate;
    DateTime previousDueDate;

    if (acc.type == 'Credit') {
      currentDueDate = currentBillEnd.add(Duration(days: dueDayOrOffset));
      previousDueDate = previousBillEnd.add(Duration(days: dueDayOrOffset));
    } else {
      int currentDueMonth = dueDayOrOffset <= billDay ? currentBillEnd.month + 1 : currentBillEnd.month;
      currentDueDate = DateTime(currentBillEnd.year, currentDueMonth, dueDayOrOffset);
      
      int prevDueMonth = dueDayOrOffset <= billDay ? previousBillEnd.month + 1 : previousBillEnd.month;
      previousDueDate = DateTime(previousBillEnd.year, prevDueMonth, dueDayOrOffset);
    }

    final currentTxs = txs.where((t) => t.date >= previousBillEnd.millisecondsSinceEpoch && t.type == 'expense').toList();
    final previousTxs = txs.where((t) => t.date >= previousBillStart.millisecondsSinceEpoch && t.date < previousBillEnd.millisecondsSinceEpoch && t.type == 'expense').toList();

    double currentSpend = currentTxs.fold(0, (s, t) => s + _calculateImpact(t));
    double previousSpend = previousTxs.fold(0, (s, t) => s + _calculateImpact(t));

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        InkWell(
          onTap: () => context.push('/statement-detail', extra: {
            'account': acc, 'type': 'Current', 'start': previousBillEnd, 'end': currentBillEnd,
            'due': currentDueDate, 'amount': currentSpend, 'txs': currentTxs, 'cats': cats
          }),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Billed On: ${DateFormat('MMM dd').format(currentBillEnd)}', style: const TextStyle(fontSize: 12)),
                          Text('Due: ${DateFormat('MMM dd, yyyy').format(currentDueDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Total Spend: ₱${currentSpend.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red)),
                        ],
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  if (acc.type == 'Credit') ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.push('/transaction-form', extra: {'mode': 'pay_bill', 'accountId': acc.id}), 
                      child: const Text('Pay Advance')
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
        InkWell(
          onTap: () => context.push('/statement-detail', extra: {
            'account': acc, 'type': 'Payment Due', 'start': previousBillStart, 'end': previousBillEnd,
            'due': previousDueDate, 'amount': previousSpend, 'txs': previousTxs, 'cats': cats
          }),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Due', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Billed On: ${DateFormat('MMM dd').format(previousBillEnd)}', style: const TextStyle(fontSize: 12)),
                          Text('Due: ${DateFormat('MMM dd, yyyy').format(previousDueDate)}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                          Text('Total Due: ₱${previousSpend.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red)),
                        ],
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.push('/transaction-form', extra: {'mode': 'pay_bill', 'accountId': acc.id}), 
                    child: const Text('Pay Bill')
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...txs.map((tx) {
          Category? cat;
          try { cat = cats.firstWhere((c) => c.id == tx.categoryId); } catch (_) {}
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
            trailing: Text('₱${_calculateImpact(tx).toStringAsFixed(2)}', style: TextStyle(color: tx.type == 'income' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: () => context.push('/transaction-form', extra: tx),
          );
        }),
      ],
    );
  }

  Widget _buildInstallmentsDashboard(List<TransactionItem> txs, List<Category> cats) {
    final installments = txs.where((t) => t.isInstallment && t.installmentCurrent != t.installmentTotal).toList();
    if (installments.isEmpty) return const Center(child: Text('No active installments.'));
    
    return ListView.builder(
      itemCount: installments.length,
      itemBuilder: (context, index) {
        final tx = installments[index];
        final total = tx.installmentTotal ?? 1;
        final current = tx.installmentCurrent ?? 0;
        final nextAmount = tx.amount / (total == 0 ? 1 : total);
        
        return Card(
          child: ListTile(
            title: Text(tx.note ?? 'Installment', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next: ₱${nextAmount.toStringAsFixed(2)} | Total: ₱${tx.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: total == 0 ? 0 : current / total),
                const SizedBox(height: 4),
                Text('Left: ₱${(tx.amount - (nextAmount * current)).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.payment, color: Colors.green), 
                  onPressed: () async {
                    final updatedTx = TransactionItem(
                      id: tx.id, amount: tx.amount, type: tx.type, categoryId: tx.categoryId,
                      accountId: tx.accountId, date: tx.date, note: tx.note,
                      isInstallment: tx.isInstallment, installmentTotal: tx.installmentTotal,
                      installmentCurrent: current + 1,
                    );
                    await ref.read(transactionsProvider.notifier).updateTransaction(updatedTx);
                    
                    final instCat = cats.firstWhere((c) => c.name == 'Installment Payment' && c.type == 'expense', orElse: () => cats.first);
                    final paymentTx = TransactionItem(
                      amount: nextAmount, type: 'expense', categoryId: instCat.id!,
                      accountId: tx.accountId, date: DateTime.now().millisecondsSinceEpoch,
                      note: '${tx.note ?? "Installment"} (${current + 2}/${tx.installmentTotal})',
                    );
                    await ref.read(transactionsProvider.notifier).addTransaction(paymentTx);
                  }
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () => ref.read(transactionsProvider.notifier).deleteTransaction(tx.id!)
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionSliverList(List<TransactionItem> txs, List<Category> cats) {
    if (txs.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('No transactions.')));
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final tx = txs[index];
          Category? cat;
          try { cat = cats.firstWhere((c) => c.id == tx.categoryId); } catch (_) {}
          final dateStr = DateFormat('MMM dd, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(tx.date));
          
          String titleText = '${cat?.icon ?? ''} ${cat?.name ?? 'Unknown'}';
          if (tx.isInstallment && tx.installmentTotal != null && tx.installmentTotal! > 0) {
            titleText += ' ${(tx.installmentCurrent ?? 0) + 1}/${tx.installmentTotal}';
          }

          return ListTile(
            onTap: () => context.push('/transaction-form', extra: tx),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (tx.note != null && tx.note!.isNotEmpty) Text(tx.note!, style: const TextStyle(fontSize: 12)),
              ],
            ),
            subtitle: Text('${tx.type.toUpperCase()} • $dateStr', style: const TextStyle(fontSize: 10)),
            trailing: Text('₱${_calculateImpact(tx).toStringAsFixed(2)}', style: TextStyle(color: tx.type == 'income' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
          );
        },
        childCount: txs.length,
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {bool isNum = false, required bool enabled, required ColorScheme colorScheme}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          enabledBorder: enabled ? const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)) : InputBorder.none,
          focusedBorder: enabled ? UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)) : InputBorder.none,
        ),
        style: TextStyle(color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant, fontSize: 14),
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
        enabled: enabled,
      ),
    );
  }

  Widget _buildStaticField(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          border: InputBorder.none,
        ),
        child: Text(value, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
      ),
    );
  }
}