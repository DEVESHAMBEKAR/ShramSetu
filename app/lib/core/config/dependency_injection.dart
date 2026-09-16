import 'package:flutter/foundation.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/repositories/i_auth_repository.dart';
import 'package:app/core/repositories/i_user_repository.dart';
import 'package:app/core/repositories/i_customer_repository.dart';
import 'package:app/core/repositories/i_worker_repository.dart';
import 'package:app/core/repositories/i_admin_repository.dart';
import 'package:app/core/repositories/i_payment_repository.dart';
import 'package:app/core/repositories/i_review_repository.dart';
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
import 'package:app/core/repositories/supabase_payment_repository.dart';
import 'package:app/core/repositories/mock_payment_repository.dart';
import 'package:app/core/repositories/supabase_review_repository.dart';
import 'package:app/core/repositories/mock_review_repository.dart';
import 'package:app/core/repositories/i_notification_repository.dart';
import 'package:app/core/repositories/supabase_notification_repository.dart';
import 'package:app/core/repositories/mock_notification_repository.dart';
import 'package:app/core/repositories/i_fairmatch_repository.dart';
import 'package:app/core/repositories/supabase_fairmatch_repository.dart';
import 'package:app/core/repositories/mock_fairmatch_repository.dart';
import 'package:app/core/repositories/i_demand_forecast_repository.dart';
import 'package:app/core/repositories/supabase_demand_forecast_repository.dart';
import 'package:app/core/repositories/mock_demand_forecast_repository.dart';
import 'package:app/core/services/location_service.dart';
import 'package:app/core/services/notification_service.dart';
import 'package:app/core/services/fairmatch_engine.dart';
import 'package:app/core/services/demand_forecasting_engine.dart';
import 'package:app/core/services/fairmatch_service.dart';
import 'package:app/core/services/demand_forecast_service.dart';

class DI {
  static late IAuthRepository authRepo;
  static late IUserRepository userRepo;
  static late ICustomerRepository customerRepo;
  static late IWorkerRepository workerRepo;
  static late IAdminRepository adminRepo;
  static late IStorageRepository storageRepo;
  static late IPaymentRepository paymentRepo;
  static late IReviewRepository reviewRepo;
  static late INotificationRepository notificationRepo;
  static late IFairMatchRepository fairMatchRepo;
  static late IDemandForecastRepository demandForecastRepo;
  static late IFairMatchService fairMatchService;
  static late IDemandForecastService demandForecastService;
  static ILocationService locationService = LocationService();
  static NotificationService notificationService = NotificationService.instance;
  static FairMatchEngine fairMatchEngine = FairMatchEngine.instance;
  static DemandForecastingEngine demandForecastEngine = DemandForecastingEngine.instance;

  static void setup() {
    locationService = LocationService();
    notificationService = NotificationService.instance;
    fairMatchEngine = FairMatchEngine.instance;
    demandForecastEngine = DemandForecastingEngine.instance;
    if (AppConfig.useMockData || AppConfig.hasConfigurationError) {
      if (AppConfig.hasConfigurationError) {
        debugPrint('[DI] Falling back to Mock repositories due to configuration error: ${AppConfig.configurationError}');
      }
      authRepo = MockAuthRepository();
      userRepo = MockUserRepository();
      customerRepo = MockCustomerRepository();
      workerRepo = MockWorkerRepository();
      adminRepo = MockAdminRepository();
      storageRepo = MockStorageRepository();
      paymentRepo = MockPaymentRepository();
      reviewRepo = MockReviewRepository();
      notificationRepo = MockNotificationRepository();
      fairMatchRepo = MockFairMatchRepository();
      demandForecastRepo = MockDemandForecastRepository(engine: demandForecastEngine);
    } else {
      authRepo = SupabaseAuthRepository(AppConfig.supabaseClient);
      userRepo = SupabaseUserRepository(AppConfig.supabaseClient);
      customerRepo = SupabaseCustomerRepository(AppConfig.supabaseClient);
      workerRepo = SupabaseWorkerRepository(AppConfig.supabaseClient);
      adminRepo = SupabaseAdminRepository(AppConfig.supabaseClient);
      storageRepo = SupabaseStorageRepository(AppConfig.supabaseClient);
      paymentRepo = SupabasePaymentRepository(AppConfig.supabaseClient);
      reviewRepo = SupabaseReviewRepository(AppConfig.supabaseClient);
      notificationRepo = SupabaseNotificationRepository(AppConfig.supabaseClient);
      fairMatchRepo = SupabaseFairMatchRepository(AppConfig.supabaseClient);
      demandForecastRepo = SupabaseDemandForecastRepository(AppConfig.supabaseClient, engine: demandForecastEngine);
    }
    fairMatchService = FairMatchService(fairMatchRepo);
    demandForecastService = DemandForecastService(demandForecastRepo, demandForecastEngine);
  }
}
