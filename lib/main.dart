import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/screens/main_root_screen.dart';
import 'ui/screens/transaction_form_screen.dart';
import 'ui/screens/account_form_screen.dart';
import 'ui/screens/transaction_list_screen.dart';
import 'ui/screens/account_detail_screen.dart';
import 'ui/screens/category_manager_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/statement_detail_screen.dart';
import 'domain/models/transaction_item.dart';
import 'services/backup_service.dart';
import 'state/providers.dart';
import 'state/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackupService.processAutoBackup();
  runApp(const ProviderScope(child: FinanceApp()));
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        return Consumer(
          builder: (context, ref, child) {
            final accountsAsync = ref.watch(accountsProvider);
            return accountsAsync.when(
              data: (accounts) => accounts.isEmpty ? const OnboardingScreen() : const MainRootScreen(),
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (err, stack) => const OnboardingScreen(),
            );
          },
        );
      },
    ),
    GoRoute(path: '/add-account', builder: (context, state) => const AccountFormScreen()),
    GoRoute(path: '/transactions', builder: (context, state) => const TransactionListScreen()),
    GoRoute(path: '/categories', builder: (context, state) => const CategoryManagerScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/transaction-form',
      builder: (context, state) {
        if (state.extra is TransactionItem) {
          return TransactionFormScreen(existingTx: state.extra as TransactionItem);
        } else if (state.extra is Map<String, dynamic>) {
          final map = state.extra as Map<String, dynamic>;
          return TransactionFormScreen(modeOverride: map['mode'], fixedDestAccountId: map['accountId']);
        }
        return const TransactionFormScreen();
      },
    ),
    GoRoute(
      path: '/account/:id',
      builder: (context, state) => AccountDetailScreen(accountId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/statement-detail',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return StatementDetailScreen(
          account: data['account'], statementType: data['type'], startDate: data['start'],
          endDate: data['end'], dueDate: data['due'], totalAmount: data['amount'],
          transactions: data['txs'], categories: data['cats'],
        );
      },
    ),
  ],
);

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeStr = ref.watch(themeProvider);
    
    ThemeMode mode;
    bool isAmoled = false;

    switch (themeStr) {
      case 'Light': mode = ThemeMode.light; break;
      case 'Dark': mode = ThemeMode.dark; break;
      case 'AMOLED Dark': mode = ThemeMode.dark; isAmoled = true; break;
      default: mode = ThemeMode.system; break;
    }

    final lightTheme = ThemeData(
      useMaterial3: true, 
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
    );
    
    final darkTheme = ThemeData(
      useMaterial3: true, 
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
    );

    final amoledTheme = darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: darkTheme.colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF121212),
        surfaceContainer: const Color(0xFF0A0A0A),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black, surfaceTintColor: Colors.black),
    );

    return MaterialApp.router(
      title: 'What-A-Budget',
      debugShowCheckedModeBanner: false, // Add this line
      themeMode: mode,
      theme: lightTheme,
      darkTheme: isAmoled ? amoledTheme : darkTheme,
      routerConfig: _router,
    );
  }
}