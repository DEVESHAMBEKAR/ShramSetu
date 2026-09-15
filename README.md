# ShramSetu – AI-Powered Cooperative Gig Worker Service Marketplace

## Project Purpose
ShramSetu is a cooperative-owned local service marketplace that connects customers with verified skilled workers such as electricians, plumbers, carpenters, painters, cleaners, caregivers, drivers, gardeners and technicians.

The platform has three roles:
1. Customer
2. Worker
3. Admin

The core research contribution is FairMatch, an AI-assisted worker-customer matching system that considers:
- skill compatibility
- distance
- availability
- rating
- experience
- workload/fairness

A secondary AI feature will be demand forecasting.

## Tech Stack
- Flutter + Dart for frontend
- Supabase + PostgreSQL for backend/database/auth/storage/realtime
- Python + FastAPI + Scikit-learn for AI
- Google Maps Platform for location
- Razorpay Test Mode for payments
- Firebase Cloud Messaging for notifications
- Git + GitHub for version control

## Architecture
- `app/` - Flutter frontend
- `ai-service/` - Python AI service
- `supabase/` - Database migrations, edge functions
- `docs/` - Project documentation
