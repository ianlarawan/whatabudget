import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/providers.dart';
import '../../domain/models/account.dart';
import '../../domain/models/interest_tier.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key});
  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final Map<String, String> _defaultIcons = {
    'Wallet': '👛', 'Savings': '🏦', 'Credit': '💳', 'Loans': '📉',
  };

  final List<String> _networks = ['Amex', 'Diners Club', 'JCB', 'Mastercard', 'UnionPay', 'Visa'];

  String _selectedType = 'Wallet';
  String _selectedNetwork = 'Mastercard';

  final _providerController = TextEditingController();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _prevBalanceController = TextEditingController();
  final _currBalanceController = TextEditingController();
  final _goalController = TextEditingController();
  final _adbController = TextEditingController(); 
  final _limitController = TextEditingController();
  final _cashAdvanceController = TextEditingController();
  final _billingDateController = TextEditingController();
  final _dueDateController = TextEditingController();

  String _interestFrequency = 'none';
  final List<InterestTier> _tiers = [];
  final _tierThresholdCtrl = TextEditingController();
  final _tierRateCtrl = TextEditingController();

  @override
  void dispose() {
    _providerController.dispose(); _nameController.dispose(); _balanceController.dispose(); 
    _prevBalanceController.dispose(); _currBalanceController.dispose(); _goalController.dispose(); 
    _adbController.dispose(); _limitController.dispose(); _cashAdvanceController.dispose(); 
    _billingDateController.dispose(); _dueDateController.dispose(); 
    _tierThresholdCtrl.dispose(); _tierRateCtrl.dispose();
    super.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_interestFrequency == 'monthly_adb' && _adbController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current ADB is required for Monthly (ADB) frequency.')));
      return;
    }

    double prev = double.tryParse(_prevBalanceController.text) ?? 0;
    double curr = double.tryParse(_currBalanceController.text) ?? 0;
    double finalBalance = ['Credit', 'Loans'].contains(_selectedType) ? (prev + curr) : (double.tryParse(_balanceController.text) ?? 0);

    final account = Account(
      type: _selectedType, provider: _providerController.text, name: _nameController.text,
      icon: _defaultIcons[_selectedType]!, balance: finalBalance,
      goalBalance: _selectedType == 'Savings' ? double.tryParse(_goalController.text) : null,
      interestRate: _selectedType == 'Savings' ? double.tryParse(_adbController.text) : null, 
      cardNetwork: _selectedType == 'Credit' ? _selectedNetwork : null,
      creditLimit: ['Credit', 'Loans'].contains(_selectedType) ? double.tryParse(_limitController.text) : null,
      cashAdvanceLimit: _selectedType == 'Credit' ? double.tryParse(_cashAdvanceController.text) : null,
      billingDate: ['Credit', 'Loans'].contains(_selectedType) ? int.tryParse(_billingDateController.text) : null,
      dueDateOffset: ['Credit', 'Loans'].contains(_selectedType) ? int.tryParse(_dueDateController.text) : null,
      interestFrequency: _selectedType == 'Savings' ? _interestFrequency : 'none',
      interestTiers: _selectedType == 'Savings' ? _tiers : const [],
      // Fix: Baseline set to exactly now. Interest will naturally evaluate starting tomorrow.
      lastInterestDate: _selectedType == 'Savings' ? DateTime.now().millisecondsSinceEpoch : null, 
    );
    
    ref.read(accountsProvider.notifier).addAccount(account, prevBalance: prev, currBalance: curr);
    
    if (context.canPop()) context.pop();
    else context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final numFormat = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    final numKeyboard = const TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Account Category'),
              items: _defaultIcons.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            TextFormField(
              controller: _providerController,
              decoration: const InputDecoration(labelText: 'Bank / Provider Name'),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Account Name'),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            
            if (['Credit', 'Loans'].contains(_selectedType)) ...[
              TextFormField(controller: _prevBalanceController, decoration: const InputDecoration(labelText: 'Previous Balance (Added to Payment Due)'), keyboardType: numKeyboard, inputFormatters: numFormat, style: const TextStyle(color: Colors.red)),
              TextFormField(controller: _currBalanceController, decoration: const InputDecoration(labelText: 'Current Balance (Added to Current Statement)'), keyboardType: numKeyboard, inputFormatters: numFormat, style: const TextStyle(color: Colors.red)),
            ] else ...[
              TextFormField(controller: _balanceController, decoration: const InputDecoration(labelText: 'Current Balance (₱)'), keyboardType: numKeyboard, inputFormatters: numFormat, validator: (val) => val!.isEmpty ? 'Required' : null),
            ],

            if (_selectedType == 'Savings') ...[
              TextFormField(controller: _goalController, decoration: const InputDecoration(labelText: 'Goal Balance (₱)'), keyboardType: numKeyboard, inputFormatters: numFormat),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Automated Interest Engine', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    DropdownButtonFormField<String>(
                      value: _interestFrequency,
                      decoration: const InputDecoration(labelText: 'Crediting Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None (Manual)')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'monthly_adb', child: Text('Monthly (ADB)')),
                      ],
                      onChanged: (val) => setState(() => _interestFrequency = val!),
                    ),
                    if (_interestFrequency == 'monthly_adb')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextFormField(controller: _adbController, decoration: const InputDecoration(labelText: 'Current ADB (₱)'), keyboardType: numKeyboard, inputFormatters: numFormat),
                      ),
                    const SizedBox(height: 16),
                    const Text('Interest Tiers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _tierThresholdCtrl, decoration: const InputDecoration(labelText: 'Balance Above (₱)', isDense: true), keyboardType: numKeyboard, inputFormatters: numFormat)),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(controller: _tierRateCtrl, decoration: const InputDecoration(labelText: 'Rate (% p.a.)', isDense: true), keyboardType: numKeyboard, inputFormatters: numFormat)),
                        IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: _addTier),
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
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => _tiers.removeAt(i))),
                        ),
                      ),
                  ],
                ),
              )
            ],

            if (['Credit', 'Loans'].contains(_selectedType)) ...[
              if (_selectedType == 'Credit') ...[
                DropdownButtonFormField<String>(value: _selectedNetwork, decoration: const InputDecoration(labelText: 'Card Network'), items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(), onChanged: (val) => setState(() => _selectedNetwork = val!)),
                TextFormField(controller: _cashAdvanceController, decoration: const InputDecoration(labelText: 'Cash Advance Limit (₱)'), keyboardType: numKeyboard, inputFormatters: numFormat),
              ],
              TextFormField(controller: _billingDateController, decoration: const InputDecoration(labelText: 'Billing/Statement Date (Day of month)'), keyboardType: numKeyboard, inputFormatters: numFormat),
              TextFormField(controller: _dueDateController, decoration: InputDecoration(labelText: _selectedType == 'Credit' ? 'Due Date (Days after billing)' : 'Payment Due Date (Day of month)'), keyboardType: numKeyboard, inputFormatters: numFormat),
              TextFormField(controller: _limitController, decoration: const InputDecoration(labelText: 'Credit Limit (₱)'), keyboardType: numKeyboard, inputFormatters: numFormat),
            ],
            const SizedBox(height: 32),
            ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), onPressed: _submit, child: const Text('Save Account', style: TextStyle(fontSize: 16))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}