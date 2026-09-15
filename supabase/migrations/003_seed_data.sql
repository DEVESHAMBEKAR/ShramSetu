-- Seed data for basic services and skills
-- Since auth.users is managed by Supabase Auth, we only seed master data here.
-- Mock/Test users should be created via the Supabase Auth API or Dashboard.

INSERT INTO public.services (id, name, description, category, icon_data, is_active) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Electrician', 'Electrical repairs and installations', 'Home Maintenance', 'electrical_services', true),
  ('22222222-2222-2222-2222-222222222222', 'Plumber', 'Plumbing fixes and pipe installations', 'Home Maintenance', 'plumbing', true),
  ('33333333-3333-3333-3333-333333333333', 'Carpenter', 'Woodwork, furniture repair and creation', 'Home Maintenance', 'carpenter', true),
  ('44444444-4444-4444-4444-444444444444', 'Painter', 'House painting and touch-ups', 'Home Maintenance', 'format_paint', true),
  ('55555555-5555-5555-5555-555555555555', 'Cleaner', 'Deep cleaning and daily sweeping', 'Cleaning', 'cleaning_services', true),
  ('66666666-6666-6666-6666-666666666666', 'Caregiver', 'Elderly care and nursing assistance', 'Care', 'elderly', true),
  ('77777777-7777-7777-7777-777777777777', 'Driver', 'Temporary and permanent drivers', 'Transport', 'drive_eta', true),
  ('88888888-8888-8888-8888-888888888888', 'Gardener', 'Plant care and landscaping', 'Home Maintenance', 'yard', true),
  ('99999999-9999-9999-9999-999999999999', 'Technician', 'Appliance repair (AC, Fridge, etc)', 'Home Maintenance', 'build', true)
ON CONFLICT DO NOTHING;

INSERT INTO public.skills (id, name) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'AC Repair'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Washing Machine Repair'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Wiring'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Pipe Leakage')
ON CONFLICT DO NOTHING;
