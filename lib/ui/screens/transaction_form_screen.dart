import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../state/providers.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/models/account.dart';
import '../../domain/models/category.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final TransactionItem? existingTx;
  final String? modeOverride;
  final int? fixedDestAccountId;

  const TransactionFormScreen({
    super.key, 
    this.existingTx, 
    this.modeOverride, 
    this.fixedDestAccountId
  });

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _mode = 'expense'; 
  late DateTime _selectedDateTime;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _totalInstCtrl = TextEditingController(text: '1');
  final _paidInstCtrl = TextEditingController(text: '0');
  int? _selectedCatId;
  int? _selectedAccId;

  final _transferAmountCtrl = TextEditingController();
  final _transferFeeCtrl = TextEditingController(text: '0');
  int? _sourceAccId;
  int? _destAccId;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTx;
    _selectedDateTime = tx != null ? DateTime.fromMillisecondsSinceEpoch(tx.date) : DateTime.now();
    
    if (widget.modeOverride != null) {
      _mode = widget.modeOverride!;
      _destAccId = widget.fixedDestAccountId;
    } else if (tx != null) {
      if (tx.isInstallment) _mode = 'installment';
      else _mode = tx.type;
      
      _amountCtrl.text = tx.amount.toString();
      _noteCtrl.text = tx.note ?? '';
      _selectedCatId = tx.categoryId;
      _selectedAccId = tx.accountId;
      _totalInstCtrl.text = tx.installmentTotal?.toString() ?? '1';
      _paidInstCtrl.text = tx.installmentCurrent?.toString() ?? '0';
    }
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(context: context, initialDate: _selectedDateTime, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDateTime));
    if (t == null) return;
    setState(() => _selectedDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_mode == 'transfer' || _mode == 'pay_bill') {
      if (_sourceAccId == null || _destAccId == null) return;
      if (_sourceAccId == _destAccId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and Destination must be different.')));
        return;
      }
      ref.read(transactionsProvider.notifier).addTransfer(
        sourceId: _sourceAccId!,
        destId: _destAccId!,
        amount: double.parse(_transferAmountCtrl.text),
        fee: double.parse(_transferFeeCtrl.text.isEmpty ? '0' : _transferFeeCtrl.text),
        date: _selectedDateTime.millisecondsSinceEpoch,
        note: _mode == 'pay_bill' ? 'Credit/Loan Bill Payment' : 'Transfer',
        categoryName: _mode == 'pay_bill' ? 'Credit/Loan Bill Payment' : 'Balance Adjustment',
      );
      context.pop();
      return;
    }

    if (_selectedCatId == null || _selectedAccId == null) return;

    final tx = TransactionItem(
      id: widget.existingTx?.id,
      amount: double.parse(_amountCtrl.text),
      type: _mode == 'installment' ? 'expense' : _mode,
      categoryId: _selectedCatId!,
      accountId: _selectedAccId!,
      date: _selectedDateTime.millisecondsSinceEpoch,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      isInstallment: _mode == 'installment',
      installmentTotal: _mode == 'installment' ? int.parse(_totalInstCtrl.text) : null,
      installmentCurrent: _mode == 'installment' ? int.parse(_paidInstCtrl.text) : null,
    );

    if (widget.existingTx == null) ref.read(transactionsProvider.notifier).addTransaction(tx);
    else ref.read(transactionsProvider.notifier).updateTransaction(tx);
    
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final accsAsync = ref.watch(accountsProvider);
    final isEdit = widget.existingTx != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == 'pay_bill' ? 'Pay Bill' : (isEdit ? 'Edit Transaction' : 'Add Transaction')),
        actions: [
          if (isEdit) 
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { 
                ref.read(transactionsProvider.notifier).deleteTransaction(widget.existingTx!.id!); 
                context.pop(); 
            }),
        ],
      ),
      body: accsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) return const Center(child: Text('Add an account first.'));
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isEdit && _mode != 'pay_bill') DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Transaction Type'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'installment', child: Text('Installment')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                  ],
                  onChanged: (val) => setState(() { _mode = val!; _selectedCatId = null; _selectedAccId = null; }),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(_selectedDateTime)),
                  onPressed: _pickDateTime,
                ),
                const SizedBox(height: 16),
                
                if (_mode == 'transfer') 
                  ..._buildTransferFields(accounts)
                else if (_mode == 'pay_bill')
                  ..._buildPayBillFields(accounts)
                else 
                  ..._buildStandardFields(accounts, catsAsync.value ?? []),

                const SizedBox(height: 24),
                ElevatedButton(onPressed: _submit, child: Text(isEdit ? 'Save Changes' : 'Save')),
              ],
            ),
          );
        }
      ),
    );
  }

  List<Widget> _buildStandardFields(List<Account> accounts, List<Category> categories) {
    List<Account> validAccounts = accounts;
    if (_mode == 'installment') {
      validAccounts = accounts.where((a) => ['Credit', 'Loans'].contains(a.type)).toList();
    }
    
    final validCats = categories.where((c) => c.type == (_mode == 'income' ? 'income' : 'expense')).toList();
    final numFormat = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];

    return [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              key: ValueKey('cat_$_mode'),
              initialValue: _selectedCatId,
              hint: const Text('Category'),
              items: validCats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}'))).toList(),
              onChanged: (val) => setState(() => _selectedCatId = val),
              validator: (v) => v == null ? 'Required' : null,
            ),
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/categories')),
        ],
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        key: ValueKey('acc_$_mode'),
        initialValue: _selectedAccId,
        hint: Text(_mode == 'installment' ? 'Select Credit/Loan Account' : 'Select Account'),
        items: validAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}'))).toList(),
        onChanged: (val) => setState(() => _selectedAccId = val),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _amountCtrl,
        decoration: InputDecoration(labelText: _mode == 'installment' ? 'Total Purchase Amount (₱)' : 'Amount (₱)'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numFormat,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      if (_mode == 'installment') ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _totalInstCtrl, decoration: const InputDecoration(labelText: 'Total Installments'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFormat)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _paidInstCtrl, decoration: const InputDecoration(labelText: 'Paid Installments'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFormat)),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Note: We will only deduct the remaining installment balance from your account.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
        )
      ],
      const SizedBox(height: 16),
      TextFormField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Name / Note')),
    ];
  }

  List<Widget> _buildTransferFields(List<Account> accounts) {
    final numFormat = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    final validAccounts = accounts.where((a) => !['Credit', 'Loans'].contains(a.type)).toList();
    
    return [
      DropdownButtonFormField<int>(
        initialValue: _sourceAccId,
        decoration: const InputDecoration(labelText: 'Source Account'),
        items: validAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}'))).toList(),
        onChanged: (val) => setState(() => _sourceAccId = val),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        initialValue: _destAccId,
        decoration: const InputDecoration(labelText: 'Destination Account'),
        items: validAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}'))).toList(),
        onChanged: (val) => setState(() => _destAccId = val),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transferAmountCtrl,
        decoration: const InputDecoration(labelText: 'Transfer Amount (₱)'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numFormat,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transferFeeCtrl,
        decoration: const InputDecoration(labelText: 'Transfer Fee (₱) - Optional'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numFormat,
      ),
    ];
  }

  List<Widget> _buildPayBillFields(List<Account> accounts) {
    final numFormat = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    final validAccounts = accounts.where((a) => !['Credit', 'Loans'].contains(a.type)).toList();
    
    return [
      DropdownButtonFormField<int>(
        initialValue: _sourceAccId,
        decoration: const InputDecoration(labelText: 'Source Account (Pay from)'),
        items: validAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}'))).toList(),
        onChanged: (val) => setState(() => _sourceAccId = val),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        initialValue: 'Credit/Loan Bill Payment',
        decoration: const InputDecoration(labelText: 'Expense Category'),
        enabled: false,
      ),
      const SizedBox(height: 16),
      TextFormField(
        initialValue: 'Credit/Loan Bill Payment',
        decoration: const InputDecoration(labelText: 'Name of Transaction'),
        enabled: false,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transferAmountCtrl,
        decoration: const InputDecoration(labelText: 'Amount (₱)'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numFormat,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transferFeeCtrl,
        decoration: const InputDecoration(labelText: 'Fee (₱) - Optional'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: numFormat,
      ),
    ];
  }
}