import 'package:flutter/material.dart';
import 'package:edu_xpress_frontend/screens/splash_screen.dart';
import 'package:edu_xpress_frontend/screens/login_screen.dart';
import 'package:edu_xpress_frontend/screens/signup_screen.dart';
import 'package:edu_xpress_frontend/screens/home_screen.dart';
import 'package:edu_xpress_frontend/screens/cart_screen.dart';
import 'package:edu_xpress_frontend/screens/orders_screen.dart';
import 'package:edu_xpress_frontend/screens/search_screen.dart';
import 'package:edu_xpress_frontend/screens/profile_screen.dart';

void main() {
  runApp(const EduXpressApp());
}

class EduXpressApp extends StatefulWidget {
  const EduXpressApp({super.key});

  @override
  State<EduXpressApp> createState() => _EduXpressAppState();
}

class _EduXpressAppState extends State<EduXpressApp> {

  bool isDark = false;

  void toggleTheme(bool value) {
    setState(() {
      isDark = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'Edu-Xpress',
  debugShowCheckedModeBanner: false,

theme: ThemeData(
  brightness: Brightness.light,

  primaryColor: const Color(0xFF7B1FA2),

  scaffoldBackgroundColor: Colors.white,

  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B1FA2),
    brightness: Brightness.light,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF7B1FA2),
    foregroundColor: Colors.white,
    elevation: 0,
  ),

  cardColor: Colors.white,

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF7B1FA2),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF7B1FA2),
  ),
),

darkTheme: ThemeData(
  brightness: Brightness.dark,

  scaffoldBackgroundColor: const Color(0xFF121212),

  cardColor: const Color(0xFF1E1E1E),

  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B1FA2),
    brightness: Brightness.dark,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF7B1FA2),
    foregroundColor: Colors.white,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF7B1FA2),
      foregroundColor: Colors.white,
    ),
  ),
),

  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

  initialRoute: '/',

  routes: {
    '/': (context) => const SplashScreen(),
    '/login': (context) => const LoginScreen(),
    '/signup': (context) => const SignupScreen(),
    '/home': (context) => const HomeScreen(),
    '/cart': (context) => const CartScreen(),
    '/orders': (context) => const OrdersScreen(),
    '/search': (context) => const SearchScreen(),

    '/profile': (context) => ProfileScreen(
      toggleTheme: toggleTheme,
      isDark: isDark,
    ),
  },
);
  }
}