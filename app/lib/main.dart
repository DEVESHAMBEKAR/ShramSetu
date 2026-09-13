import 'package:app/core/config/dependency_injection.dart';
import 'package:flutter/material.dart';
import 'package:app/core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/customer/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/customer_login_screen.dart';
import 'features/customer/presentation/screens/onboarding_screen.dart';
import 'features/customer/presentation/screens/customer_main_layout.dart';
import 'features/worker/presentation/screens/worker_main_layout.dart';
import 'features/admin/presentation/screens/admin_login_screen.dart';
import 'features/admin/presentation/screens/admin_main_layout.dart';
import 'features/auth/presentation/screens/worker_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  DI.setup();
  runApp(const ShramSetuApp());
}

class ShramSetuApp extends StatelessWidget {
  const ShramSetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShramSetu',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login/customer': (context) => const CustomerLoginScreen(),
        '/login/worker': (context) => const WorkerLoginScreen(),
        '/customer/home': (context) => const CustomerMainLayout(),
        '/worker/dashboard': (context) => const WorkerMainLayout(),
        '/login/admin': (context) => const AdminLoginScreen(),
        '/admin/home': (context) => const AdminMainLayout(),
      },
    );
  }

}

