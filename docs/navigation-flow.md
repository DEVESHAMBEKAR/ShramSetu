# Navigation Flow

Based on the available Stitch screens, here is the implied navigation flow. *(Note: The actual code contains no functional routers; these flows are inferred from the visual purpose of the standalone HTML files).*

## CUSTOMER Flow
1. **Onboarding**: `sharmsetu_onboarding_language_selection`
2. **Login**: `sharmsetu_customer_mobile_otp_login`
3. **Home**: `sharmsetu_customer_home_marketplace`
4. **Discovery**: `sharmsetu_service_discovery_workers`
5. **Worker Profile**: `sharmsetu_worker_profile_rahul_patil`
6. **Payment**: `sharmsetu_booking_escrow_payment`
7. **Tracking/Active Jobs**: `sharmsetu_customer_live_booking_tracking`, `sharmsetu_customer_booking_history_active_orders`
8. **Review**: `sharmsetu_customer_rating_review`

## WORKER Flow
1. **Verification/KYC**: `sharmsetu_worker_kyc_skill_verification`
2. **Dashboard**: `sharmsetu_worker_home_dashboard`
3. **Job Detail**: `sharmsetu_worker_job_detail_execution`
4. **Earnings/Welfare**: `sharmsetu_worker_earnings_welfare`

## ADMIN Flow
1. **Dashboard**: `sharmsetu_cooperative_admin_console` (single monolithic console view)

*(Flows for missing screens such as customer profile, admin worker management, etc. are currently non-existent in the visual prototype).*
