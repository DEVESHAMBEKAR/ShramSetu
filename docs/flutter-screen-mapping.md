# Flutter Screen Mapping

This document maps the Stitch static HTML prototypes to their future Flutter screens.

## Customer Flow
| Stitch Screen | Future Flutter Screen Path |
| --- | --- |
| `sharmsetu_onboarding_language_selection` | `features/customer/presentation/screens/onboarding_screen.dart` |
| `sharmsetu_customer_mobile_otp_login` | `features/auth/presentation/screens/customer_login_screen.dart` |
| `sharmsetu_customer_home_marketplace` | `features/customer/presentation/screens/home_screen.dart` |
| `sharmsetu_service_discovery_workers` | `features/customer/presentation/screens/service_discovery_screen.dart` |
| `sharmsetu_worker_profile_rahul_patil` | `features/customer/presentation/screens/worker_profile_screen.dart` |
| `sharmsetu_booking_escrow_payment` | `features/customer/presentation/screens/escrow_payment_screen.dart` |
| `sharmsetu_customer_live_booking_tracking` | `features/customer/presentation/screens/live_tracking_screen.dart` |
| `sharmsetu_customer_booking_history_active_orders` | `features/customer/presentation/screens/booking_history_screen.dart` |
| `sharmsetu_customer_rating_review` | `features/customer/presentation/screens/rating_review_screen.dart` |
| `[MISSING]` Service Details | `features/customer/presentation/screens/service_detail_screen.dart` |
| `[MISSING]` Customer Profile/Settings | `features/customer/presentation/screens/profile_screen.dart` |

## Worker Flow
| Stitch Screen | Future Flutter Screen Path |
| --- | --- |
| `[MISSING]` Worker Login | `features/auth/presentation/screens/worker_login_screen.dart` |
| `sharmsetu_worker_kyc_skill_verification` | `features/worker/presentation/screens/kyc_verification_screen.dart` |
| `sharmsetu_worker_home_dashboard` | `features/worker/presentation/screens/worker_dashboard_screen.dart` |
| `sharmsetu_worker_job_detail_execution` | `features/worker/presentation/screens/job_detail_screen.dart` |
| `sharmsetu_worker_earnings_welfare` | `features/worker/presentation/screens/earnings_screen.dart` |
| `[MISSING]` Worker Profile/Settings | `features/worker/presentation/screens/worker_profile_screen.dart` |

## Admin Flow
| Stitch Screen | Future Flutter Screen Path |
| --- | --- |
| `[MISSING]` Admin Login | `features/auth/presentation/screens/admin_login_screen.dart` |
| `sharmsetu_cooperative_admin_console` | `features/admin/presentation/screens/admin_console_screen.dart` |

## Shared/Other
| Stitch Screen | Future Flutter Screen Path |
| --- | --- |
| `cooperative_trust` | `features/customer/presentation/widgets/trust_banner.dart` |
| `sharmsetu_logo` | `shared/widgets/app_logo.dart` |
