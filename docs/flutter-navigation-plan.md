# Flutter Navigation Plan

## Overview
This document outlines the initial navigation routes and flow plan for the ShramSetu application. No complex routing library (like auto_route or go_router) is strictly necessary right away; standard `Navigator` can be used until deep linking is required.

## Auth Routes (Unauthenticated)
| Route Name | Screen | Role | Next Screens |
| --- | --- | --- | --- |
| `/onboarding` | `OnboardingScreen` | Any | `/login` (Customer/Worker/Admin selection) |
| `/login/customer` | `CustomerLoginScreen` | Customer | `/customer/home` |
| `/login/worker` | `WorkerLoginScreen` | Worker | `/worker/dashboard` or `/worker/kyc` |
| `/login/admin` | `AdminLoginScreen` | Admin | `/admin/console` |

## Customer Routes (Authenticated Customer)
| Route Name | Screen | Next Screens |
| --- | --- | --- |
| `/customer/home` | `HomeScreen` | `/customer/discovery`, `/customer/history` |
| `/customer/discovery` | `ServiceDiscoveryScreen` | `/customer/worker_profile` |
| `/customer/worker_profile`| `WorkerProfileScreen` | `/customer/booking/payment` |
| `/customer/booking/payment`| `EscrowPaymentScreen` | `/customer/booking/tracking` |
| `/customer/booking/tracking`| `LiveTrackingScreen` | `/customer/review` |
| `/customer/review` | `RatingReviewScreen` | `/customer/home` |
| `/customer/history` | `BookingHistoryScreen` | `/customer/booking/tracking` |

## Worker Routes (Authenticated Worker)
| Route Name | Screen | Next Screens |
| --- | --- | --- |
| `/worker/kyc` | `KycVerificationScreen`| `/worker/dashboard` |
| `/worker/dashboard` | `WorkerDashboardScreen` | `/worker/job_detail`, `/worker/earnings` |
| `/worker/job_detail`| `JobDetailScreen` | `/worker/dashboard` |
| `/worker/earnings` | `EarningsScreen` | `/worker/dashboard` |

## Admin Routes (Authenticated Admin)
| Route Name | Screen | Next Screens |
| --- | --- | --- |
| `/admin/console` | `AdminConsoleScreen` | Modal detail views (No sub-routes yet) |
