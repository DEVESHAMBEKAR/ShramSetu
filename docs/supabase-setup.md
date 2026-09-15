# Supabase Setup

## Overview
This document outlines the steps to configure and run ShramSetu against a Supabase backend. The application is designed to support both local mock data (for rapid UI iteration and testing) and live Supabase environments.

## Environment Variables
The application relies on `flutter_dotenv` to manage secrets. 
1. Create a `.env` file in `app/`.
2. Do **NOT** commit the `.env` file. It is ignored in `.gitignore`.

Required variables:
```env
SUPABASE_URL=https://[YOUR_PROJECT_ID].supabase.co
SUPABASE_ANON_KEY=[YOUR_PUBLISHABLE_ANON_KEY]

# Feature Flag (true = Local UI Mock mode, false = Supabase mode)
USE_MOCK_DATA=false
```

### Security Rule
**NEVER put the Supabase service-role key in the `.env` file or anywhere in the Flutter application.** Only use the `anon` key.

## Applying Migrations
All schema and RLS policies are stored in `supabase/migrations/`. 

If using the Supabase CLI locally:
```bash
cd supabase
supabase start
supabase db reset
```

If applying to a remote project, you can use the CLI or run the SQL files directly in the Supabase Studio SQL Editor in the following order:
1. `001_initial_schema.sql`
2. `002_rls_policies.sql`
3. `003_seed_data.sql`

## Mock vs Supabase Repository Architecture
The app uses a Dependency Injection container `DI` (`lib/core/config/dependency_injection.dart`). 

When `USE_MOCK_DATA=true`, `DI.setup()` injects `MockAuthRepository`.
When `USE_MOCK_DATA=false`, `DI.setup()` injects `SupabaseAuthRepository`.

This guarantees the Flutter UI logic remains decoupled from the backend implementation.
