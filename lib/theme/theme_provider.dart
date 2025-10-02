import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parcel_box_app/theme/theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentThemeData = lightMode;

  ThemeData get currentThemeData => _currentThemeData;
  ThemeProvider() {
    loadTheme();
  }

  set currentThemeData(ThemeData themeData) {
    _currentThemeData = themeData;
    notifyListeners();
  }

  void toggleTheme() {
    if (_currentThemeData == lightMode) {
      currentThemeData = darkMode;
    } else {
      currentThemeData = lightMode;
    }

    saveTheme();
    notifyListeners();
  }

  void saveTheme() async {
    String themeString = currentThemeData == lightMode ? 'light' : 'dark';
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('setTheme', themeString);
  }

  void loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? themeString = prefs.getString('setTheme');
    if (themeString == 'light') {
      currentThemeData = lightMode;
    } else if (themeString == 'dark') {
      currentThemeData = darkMode;
    }
    notifyListeners();
  }
}