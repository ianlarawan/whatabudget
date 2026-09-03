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
import '../../utils/number_formatters.dart';
import '../../utils/statement_engine.dart';

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

  void _showEditInstallmentDialog(List<TransactionItem> group) {
    // Passes the exact pre-grouped logic array to bypass filtering failures
    group.sort((a, b) => (a.installmentCurrent ?? 0).compareTo(b.installmentCurrent ?? 0));
    final baseTx = group.first;

    List<TextEditingController> controllers = group.map((t) {
      double exactAmount = t.amount / (t.installmentTotal ?? 1);
      return TextEditingController(text: exactAmount.toStringAsFixed(2));
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Pending Installments'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining months', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: controllers.length > 1 ? () {
                              setState(() {
                                controllers.last.dispose();
                                controllers.removeLast();
                              });
                            } : null,
                          ),
                          Text('${controllers.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                controllers.add(TextEditingController(text: '0.00'));
                              });
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: controllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              SizedBox(width: 70, child: Text('Month ${index + 1}:')),
                              Expanded(
                                child: TextFormField(
                                  controller: controllers[index],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true, 
                                    prefixText: '₱ ',
                                    border: OutlineInputBorder()
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  List<double> exactAmounts = controllers
                      .map((c) => double.tryParse(c.text) ?? 0.0)
                      .toList();
                  ref.read(transactionsProvider.notifier).updateInstallmentPlan(
                    baseTx: baseTx,
                    exactAmounts: exactAmounts,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
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
                                : _buildStaticField('Current ADB', '₱${acc.interestRate?.toCurrency() ?? "0.00"}', colorScheme),
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
                                title: Text('> ₱${_tiers[i].threshold.toCurrency()}'),
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
                        Text('₱${(acc.goalBalance! - acc.balance).clamp(0.0, double.infinity).toCurrency()} Left', style: const TextStyle(fontSize: 12)),
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
                          // FIXED: Removed flawed unbilled recalculation. Native account balance inherently tracks array sums.
                          double available = acc.creditLimit! - acc.balance;
                          return Align(
                            alignment: Alignment.centerLeft, 
                            child: Text('Available Credit: ₱${available.toCurrency()}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12))
                          );
                        }
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: TabBar(tabs: [
                Tab(text: 'Statements'), 
                Tab(text: 'Installments'), 
                Tab(text: 'Statement History') 
              ]),
            ),
          ],
          body: TabBarView(
            children: [
              _buildAutomatedStatementsList(acc, txs, cats, colorScheme),
              _buildInstallmentsDashboard(txs, cats),
              _buildStatementHistoryTab(acc, txs, cats, colorScheme), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutomatedStatementsList(Account acc, List<TransactionItem> txs, List<Category> cats, ColorScheme colorScheme) {
    final computedStatements = StatementEngine.generateStatements(account: acc, transactions: txs);

    if (computedStatements.isEmpty) {
      return const Center(child: Text('No structured bill logs computed.'));
    }

    final activeUnbilled = computedStatements[0];
    final activePaymentDue = computedStatements[1];

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildStatementCard(acc, activeUnbilled, cats, colorScheme),
        _buildStatementCard(acc, activePaymentDue, cats, colorScheme, requirePayButton: true),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text('All Account Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...txs.where((t) => t.type == 'expense').map((tx) {
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
            trailing: Text('₱${_calculateImpact(tx).toCurrency()}', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: () => context.push('/transaction-form', extra: tx),
          );
        }),
      ],
    );
  }

  Widget _buildStatementHistoryTab(Account acc, List<TransactionItem> txs, List<Category> cats, ColorScheme colorScheme) {
    final computedStatements = StatementEngine.generateStatements(account: acc, transactions: txs);
    
    if (computedStatements.length <= 2) {
      return const Center(
        child: Text('Statement History\nNo historical statements archived.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    final historicalArchive = computedStatements.skip(2).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: historicalArchive.length,
      itemBuilder: (context, index) {
        return _buildStatementCard(acc, historicalArchive[index], cats, colorScheme, isArchived: true);
      },
    );
  }

  Widget _buildStatementCard(Account acc, Statement st, List<Category> cats, ColorScheme colorScheme, {bool requirePayButton = false, bool isArchived = false}) {
    final bool displayPaid = st.isPaid;
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;

    Color? cardBackground;
    BorderSide? cardBorder;

    if (displayPaid) {
      cardBackground = isLightMode 
          ? Colors.green.shade50.withOpacity(0.5) 
          : Colors.green.withOpacity(0.06);       
      cardBorder = BorderSide(color: isLightMode ? Colors.green.shade300 : Colors.green.shade700, width: 1);
    } else if (isArchived) {
      cardBackground = colorScheme.surfaceContainerLow;
    }

    return InkWell(
      onTap: () => context.push('/statement-detail', extra: {
        'account': acc, 
        'type': st.label, 
        'start': st.billingDate.subtract(const Duration(days: 30)), 
        'end': st.billingDate,
        'due': st.dueDate, 
        'amount': st.totalAmount, 
        'txs': st.transactions, 
        'cats': cats
      }),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        elevation: (isArchived || displayPaid) ? 0 : 1, 
        color: cardBackground,
        shape: cardBorder != null 
            ? RoundedRectangleBorder(side: cardBorder, borderRadius: BorderRadius.circular(12))
            : null,
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
                      Row(
                        children: [
                          Text(st.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (displayPaid) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLightMode ? Colors.green.shade600 : Colors.green, 
                                borderRadius: BorderRadius.circular(6)
                              ),
                              child: const Text(
                                'PAID', 
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text('Statement Cut: ${DateFormat('MMM dd, yyyy').format(st.billingDate)}', style: const TextStyle(fontSize: 11)),
                      Text('Payment Deadline: ${DateFormat('MMM dd, yyyy').format(st.dueDate)}', 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (requirePayButton && !displayPaid) ? Colors.red : null)),
                      const SizedBox(height: 4),
                      Text(
                        displayPaid ? 'Remaining Balance: ₱0.00' : 'Statement Total: ₱${st.amountDue.toCurrency()}', 
                        style: TextStyle(
                          fontSize: 15, 
                          color: displayPaid 
                              ? (isLightMode ? Colors.green.shade700 : Colors.green) 
                              : Colors.red, 
                          fontWeight: FontWeight.w700
                        )
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              if (requirePayButton && !displayPaid) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 16),
                  onPressed: () => context.push('/transaction-form', extra: {'mode': 'pay_bill', 'accountId': acc.id}), 
                  label: const Text('Pay Statement Balance', style: TextStyle(fontSize: 12))
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallmentsDashboard(List<TransactionItem> txs, List<Category> cats) {
    final allInstallments = txs.where((t) => t.isInstallment).toList();
    if (allInstallments.isEmpty) return const Center(child: Text('No active installments.'));
    
    final Map<String, List<TransactionItem>> grouped = {};
    for (var t in allInstallments) {
      final key = '${t.note}_${t.installmentTotal}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    
    final uniqueGroups = grouped.values.toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return ListView.builder(
      itemCount: uniqueGroups.length,
      itemBuilder: (context, index) {
        final group = uniqueGroups[index];
        group.sort((a, b) => (a.installmentCurrent ?? 0).compareTo(b.installmentCurrent ?? 0));
        final baseTx = group.first;
        
        final grandTotal = group.fold(0.0, (sum, t) => sum + (t.amount / (t.installmentTotal ?? 1)));
        final billedLegs = group.where((t) => t.date <= now).toList();
        final billedTotal = billedLegs.fold(0.0, (sum, t) => sum + (t.amount / (t.installmentTotal ?? 1)));
        final remaining = grandTotal - billedTotal;
        
        final totalMonths = baseTx.installmentTotal ?? 1;
        final currentMonthsBilled = billedLegs.length;
        
        // Hide fully billed installments natively
        if (currentMonthsBilled >= totalMonths) return const SizedBox.shrink();

        final unbilledLegs = group.where((t) => t.date > now).toList();
        final exactNextAmount = unbilledLegs.isNotEmpty ? (unbilledLegs.first.amount / (unbilledLegs.first.installmentTotal ?? 1)) : 0.0;
        
        return Card(
          child: ListTile(
            title: Text(baseTx.note ?? 'Installment', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next: ₱${exactNextAmount.toCurrency()} | Total: ₱${grandTotal.toCurrency()}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: totalMonths == 0 ? 0 : currentMonthsBilled / totalMonths),
                const SizedBox(height: 4),
                Text('Left: ₱${remaining.toCurrency()}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditInstallmentDialog(group),
                ),
                // FIXED: Manual payment button deleted to respect statement engine passive collection rules
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () {
                    for (var leg in group) {
                      ref.read(transactionsProvider.notifier).deleteTransaction(leg.id!);
                    }
                  }
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
            int displayIndex = (tx.installmentCurrent == tx.installmentTotal) 
                ? tx.installmentTotal! 
                : (tx.installmentCurrent ?? 0) + 1;
            titleText += ' $displayIndex/${tx.installmentTotal}';
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
            trailing: Text('₱${_calculateImpact(tx).toCurrency()}', style: TextStyle(color: tx.type == 'income' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
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