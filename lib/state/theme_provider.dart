import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = NotifierProvider<ThemeNotifier, String>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<String> {
  @override
  String build() {
    _loadTheme();
    return 'System';
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('theme_mode') ?? 'System';
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', theme);
    state = theme;
  }
}