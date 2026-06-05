import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'all_spending_screen.dart';
import 'calculator_view.dart';
import 'currency_matrix_view.dart';

class MainRootScreen extends StatefulWidget {
  const MainRootScreen({super.key});

  @override
  State<MainRootScreen> createState() => _MainRootScreenState();
}

class _MainRootScreenState extends State<MainRootScreen> {
  int _bottomNavIndex = 0; // Tracks Home, Transactions, All Spending
  int _workspaceViewIndex = 0; // 0 = Core App Tabs, 1 = Calculator, 2 = Currency Matrix

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine the AppBar Title text dynamically based on the active Drawer selection
    String appBarTitle = 'What-A-Budget';
    if (_workspaceViewIndex == 1) appBarTitle = 'Calculator';
    if (_workspaceViewIndex == 2) appBarTitle = 'Currency Matrix';

    if (_workspaceViewIndex == 0) {
      // Dynamic title adjustment based on the selected bottom navigation bar index
      if (_bottomNavIndex == 1) appBarTitle = 'Transactions';
      if (_bottomNavIndex == 2) appBarTitle = 'All Spending';
    } else if (_workspaceViewIndex == 1) {
      appBarTitle = 'Calculator';
    } else if (_workspaceViewIndex == 2) {
      appBarTitle = 'Currency Matrix';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        // Left side now houses the Hamburger Menu Drawer open signal hook
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        // Right side houses the Wallet shortcut button (Displays only when looking at Core App Views)
        actions: [
          if (_workspaceViewIndex == 0)
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'Add Account',
              onPressed: () => context.push('/add-account'),
            ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colorScheme.primaryContainer),
              child: Center(
                child: Text(
                  'Tools & Utilities',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Home'),
              selected: _workspaceViewIndex == 0,
              onTap: () {
                setState(() => _workspaceViewIndex = 0);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Calculator'),
              selected: _workspaceViewIndex == 1,
              onTap: () {
                setState(() => _workspaceViewIndex = 1);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange_outlined),
              title: const Text('Currency Matrix'),
              selected: _workspaceViewIndex == 2,
              onTap: () {
                setState(() => _workspaceViewIndex = 2);
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      // Multiplex between the primary app sub-views and workspace modules
      body: IndexedStack(
        index: _workspaceViewIndex,
        children: [
          // Index 0: Core financial navigation tabs
          IndexedStack(
            index: _bottomNavIndex,
            children: const [
              DashboardScreen(),
              TransactionsScreen(),
              AllSpendingScreen(),
            ],
          ),
          // Index 1: Tools view modules
          const CalculatorView(),
          const CurrencyMatrixView(),
        ],
      ),
      // Only show the primary tabs bar bottom strip when home dashboard environment is active
      bottomNavigationBar: _workspaceViewIndex == 0
          ? NavigationBar(
              selectedIndex: _bottomNavIndex,
              onDestinationSelected: (index) => setState(() => _bottomNavIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
                NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'All Spending'),
              ],
            )
          : null,
    );
  }
}