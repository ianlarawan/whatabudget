import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditBudgetScreen extends StatefulWidget {
  final double currentAmount;
  final String currentFreq;
  final DateTime currentStart;

  const EditBudgetScreen({
    super.key,
    required this.currentAmount,
    required this.currentFreq,
    required this.currentStart,
  });

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  late TextEditingController _budgetCtrl;
  late String _budgetFreq;
  late DateTime _budgetStartDate;

  @override
  void initState() {
    super.initState();
    _budgetCtrl = TextEditingController(text: widget.currentAmount.toStringAsFixed(2));
    _budgetFreq = widget.currentFreq;
    _budgetStartDate = widget.currentStart;
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _budgetStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _budgetStartDate) {
      setState(() {
        _budgetStartDate = picked;
      });
    }
  }

    // Modify _saveChanges
  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    if (_budgetCtrl.text.isNotEmpty) {
      double? amount = double.tryParse(_budgetCtrl.text);
      if (amount != null && amount > 0) {
        await prefs.setDouble('budget_amount', amount);
        await prefs.setString('budget_frequency', _budgetFreq);
        await prefs.setInt('budget_start_date', _budgetStartDate.millisecondsSinceEpoch);
      }
    }
    // Change from context.go('/') to context.pop(true)
    if (mounted) context.pop(true);
  }

  // Modify _deleteBudget
  Future<void> _deleteBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('budget_amount');
    await prefs.remove('budget_frequency');
    await prefs.remove('budget_start_date');
    
    // Change from context.go('/') to context.pop(true)
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Budget')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _budgetCtrl,
              decoration: InputDecoration(
                labelText: 'Target Budget Amount (₱)',
                prefixIcon: const Icon(Icons.account_balance_wallet),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _budgetFreq,
              decoration: InputDecoration(
                labelText: 'Budget Frequency',
                prefixIcon: const Icon(Icons.calendar_month),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'Bi-Weekly', child: Text('Bi-Weekly')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
              ],
              onChanged: (val) => setState(() => _budgetFreq = val!),
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Budget Start Date'),
              subtitle: Text('${_budgetStartDate.month}/${_budgetStartDate.day}/${_budgetStartDate.year}'),
              trailing: const Icon(Icons.calendar_today),
              shape: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline, width: 1),
              ),
              tileColor: colorScheme.surfaceContainerHighest,
              onTap: () => _selectStartDate(context),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saveChanges,
              child: const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                minimumSize: const Size(double.infinity, 56),
                side: BorderSide(color: colorScheme.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _deleteBudget,
              child: const Text('Delete Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}