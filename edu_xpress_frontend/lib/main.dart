import 'package:flutter/material.dart';
import 'package:edu_xpress_frontend/screens/splash_screen.dart';
import 'package:edu_xpress_frontend/screens/login_screen.dart';
import 'package:edu_xpress_frontend/screens/signup_screen.dart';
import 'package:edu_xpress_frontend/screens/home_screen.dart';
import 'package:edu_xpress_frontend/screens/cart_screen.dart';
import 'package:edu_xpress_frontend/screens/orders_screen.dart';
import 'package:edu_xpress_frontend/screens/search_screen.dart';
import 'package:edu_xpress_frontend/screens/profile_screen.dart';
import 'package:edu_xpress_frontend/screens/chat_screen.dart';
import 'package:edu_xpress_frontend/screens/address_screen.dart';
import 'package:edu_xpress_frontend/screens/track_order_screen.dart';
import 'package:edu_xpress_frontend/services/live_tracking_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  navigatorKey: navigatorKey,
  title: 'Edu-Xpress',
  debugShowCheckedModeBanner: false,

theme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepOrange,
    brightness: Brightness.light,
    surface: const Color(0xFFF4F7FA),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.deepOrange,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepOrange,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
    ),
  ),
),

darkTheme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepOrange,
    brightness: Brightness.dark,
    surface: const Color(0xFF121212),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1E1E1E),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepOrange,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2C2C2C),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
    ),
  ),
),

  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

  initialRoute: '/',

  builder: (context, child) {
    return Stack(
      children: [
        child!,
        const LiveTrackingOverlay(),
      ],
    );
  },

  routes: {
    '/': (context) => const SplashScreen(),
    '/login': (context) => const LoginScreen(),
    '/signup': (context) => const SignupScreen(),
    '/home': (context) => const HomeScreen(),
    '/cart': (context) => const CartScreen(),
    '/orders': (context) => const OrdersScreen(),
    '/search': (context) => const SearchScreen(),
    '/chat': (context) => const ChatScreen(),
    '/addresses': (context) => AddressScreen(),
    '/track_order': (context) => TrackOrderScreen(),

    '/profile': (context) => ProfileScreen(
      toggleTheme: toggleTheme,
      isDark: isDark,
    ),
  },
);
  }
}