import 'package:app/core/config/app_config.dart';
import 'package:app/core/repositories/i_auth_repository.dart';
import 'package:app/core/repositories/i_user_repository.dart';
import 'package:app/core/repositories/i_customer_repository.dart';
import 'package:app/core/repositories/i_worker_repository.dart';
import 'package:app/core/repositories/i_admin_repository.dart';
import 'package:app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:app/features/auth/data/repositories/supabase_user_repository.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/customer/data/repositories/supabase_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/worker/data/repositories/supabase_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:app/features/admin/data/repositories/supabase_admin_repository.dart';
import 'package:app/core/repositories/i_storage_repository.dart';
import 'package:app/core/repositories/supabase_storage_repository.dart';
import 'package:app/core/repositories/mock_storage_repository.dart';

class DI {
  static late IAuthRepository authRepo;
  static late IUserRepository userRepo;
  static late ICustomerRepository customerRepo;
  static late IWorkerRepository workerRepo;
  static late IAdminRepository adminRepo;
  static late IStorageRepository storageRepo;

  static void setup() {
    if (AppConfig.useMockData) {
      authRepo = MockAuthRepository();
      userRepo = MockUserRepository();
      customerRepo = MockCustomerRepository();
      workerRepo = MockWorkerRepository();
      adminRepo = MockAdminRepository();
      storageRepo = MockStorageRepository();
    } else {
      authRepo = SupabaseAuthRepository(AppConfig.supabaseClient);
      userRepo = SupabaseUserRepository(AppConfig.supabaseClient);
      customerRepo = SupabaseCustomerRepository(AppConfig.supabaseClient);
      workerRepo = SupabaseWorkerRepository(AppConfig.supabaseClient);
      adminRepo = SupabaseAdminRepository(AppConfig.supabaseClient);
      storageRepo = SupabaseStorageRepository(AppConfig.supabaseClient);
    }
  }
}
