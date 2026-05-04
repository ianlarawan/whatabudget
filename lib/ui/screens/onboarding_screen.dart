import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backup_service.dart';
import '../../state/theme_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _budgetCtrl = TextEditingController();
  String _budgetFreq = 'Monthly';
  bool _isRestoring = false;
  DateTime _budgetStartDate = DateTime.now();

  @override
  void dispose() {
    _pageController.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);
    bool success = await BackupService.restoreBackup(ref);
    setState(() => _isRestoring = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore successful! Welcome back.')),
        );
        context.go('/'); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore cancelled or failed.')),
        );
      }
    }
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

  Future<void> _saveBudgetAndContinue() async {
  final prefs = await SharedPreferences.getInstance();
  
  if (_budgetCtrl.text.isNotEmpty) {
    double? amount = double.tryParse(_budgetCtrl.text);
    if (amount != null && amount > 0) {
      await prefs.setDouble('budget_amount', amount);
      await prefs.setString('budget_frequency', _budgetFreq);
      // Replaced DateTime.now() with user selection
      await prefs.setInt('budget_start_date', _budgetStartDate.millisecondsSinceEpoch);
    }
  }
  
  if (mounted) context.push('/add-account');
}

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), 
          children: [
            _buildWelcomePage(colorScheme, currentTheme),
            _buildBudgetPage(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ColorScheme colorScheme, String currentTheme) {
    return Stack(
      children: [
        // Theme Toggle
        Positioned(
          top: 16,
          right: 16,
          child: PopupMenuButton<String>(
            icon: Icon(Icons.brightness_6, color: colorScheme.onSurfaceVariant),
            tooltip: 'Change Theme',
            initialValue: currentTheme,
            onSelected: (val) => ref.read(themeProvider.notifier).setTheme(val),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'System', child: Text('System Default')),
              PopupMenuItem(value: 'Light', child: Text('Light')),
              PopupMenuItem(value: 'Dark', child: Text('Dark')),
              PopupMenuItem(value: 'AMOLED Dark', child: Text('AMOLED Dark')),
            ],
          ),
        ),
        
        // Main Content
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Asset Image with safe fallback
                Image.asset(
                  'assets/app_icon.png',
                  height: 120,
                  width: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.account_balance_wallet,
                      size: 100,
                      color: colorScheme.primary,
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                Text(
                  'Welcome to',
                  style: TextStyle(fontSize: 20, color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  'What-A-Budget',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your offline, private, and powerful personal finance tracker.',
                  style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Start Fresh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isRestoring 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.restore),
                  onPressed: _isRestoring ? null : _handleRestore,
                  label: Text(_isRestoring ? 'Restoring...' : 'Restore from Backup', style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

    Widget _buildBudgetPage(ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 16),
                Text(
                  'Set Your Budget',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s establish a baseline to track your spending. You can always change or skip this later in the dashboard.',
                  style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
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
                  style: const TextStyle(fontSize: 18),
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
                  onPressed: _saveBudgetAndContinue,
                  child: const Text('Continue to Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push('/add-account'),
                  style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                  child: const Text('Skip for now'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}