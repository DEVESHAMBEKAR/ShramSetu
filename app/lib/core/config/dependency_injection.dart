import 'package:app/core/config/app_config.dart';
import 'package:app/core/repositories/i_auth_repository.dart';
import 'package:app/core/repositories/i_user_repository.dart';
import 'package:app/core/repositories/i_customer_repository.dart';
import 'package:app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:app/features/auth/data/repositories/supabase_user_repository.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/customer/data/repositories/supabase_customer_repository.dart';

class DI {
  static late IAuthRepository authRepo;
  static late IUserRepository userRepo;
  static late ICustomerRepository customerRepo;

  static void setup() {
    if (AppConfig.useMockData) {
      authRepo = MockAuthRepository();
      userRepo = MockUserRepository();
      customerRepo = MockCustomerRepository();
    } else {
      authRepo = SupabaseAuthRepository(AppConfig.supabaseClient);
      userRepo = SupabaseUserRepository(AppConfig.supabaseClient);
      customerRepo = SupabaseCustomerRepository(AppConfig.supabaseClient);
    }
  }
}
