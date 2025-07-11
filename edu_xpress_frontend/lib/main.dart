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

class EduXpressApp extends StatelessWidget {
  const EduXpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edu-Xpress',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/home': (_) => const HomeScreen(),
        '/cart': (_) => const CartScreen(),
        '/orders': (_) => const OrdersScreen(),
        '/search': (_) => const SearchScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
