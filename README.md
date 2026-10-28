# RoadTrack Mobile

Public accident reporting companion to the React web manager. Both clients connect to the same Supabase backend. Architecture, migration, permissions, and setup details are documented in `../supabase/README.md`.

## Experience

- Public home with a prominent Report an Accident action, account sign-in/registration, recent own reports, and report updates.
- Accident details, occurrence time (happening now or selected time), injury information, and optional camera/gallery evidence.
- Light street map with GPS acquisition, fixed height, pinch/+/- zoom, in-map location control, manual repinning, and explicit confirmation. No radius controls.
- Review, sign-in if needed, persisted report submission, private evidence upload, and a server-generated reference.
- Report tracking, history, in-app notifications, private photo viewing, and responding to clarification requests. Lists refresh every 15 seconds while open.

The website handles verification and responder assignment. A saved report is distinguished from a report whose photos still need upload retry. Drafts and pending photo uploads are held only while the screen is open; they are not a durable offline queue.

## Run and verify

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Public Supabase configuration defaults to the connected development project. Override using SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY dart defines for a different project; never use a service-role key. Fully restart after plugin installation.

Android foreground location/internet permissions are configured. Camera/gallery uses image_picker and Android system pickers. There is no iOS runner in this workspace; a future iOS runner needs location, camera, and photo-library usage descriptions. Native camera/map/GPS behavior still requires device testing. An internet connection is needed for map tiles, authentication, submissions, and updates.

New registration collects full name, email and password. The name is saved on the profile; email is the sign-in identity. Existing username accounts still sign in through Email or username using their original credentials. The server retains the legacy username registration contract for older clients. Supabase Auth handles password hashing and sessions; the existing immediate-sign-in/no-confirmation-email policy is retained, so the supplied email is not verified by this flow. Enforcer applicants remain Public until Admin approval.

## R07 reporter policy

New reports require full name and contact number (1–120 trimmed characters each), plus the existing sign-in. Both fields validate before review. Previously saved reports and their stable-ID retries retain optional legacy identities. Explicit server identity-policy rejections return the updated app to editable contact fields. Older clients submitting blanks are rejected by the new backend policy; update the app or restart the draft with both fields supplied. Admin-corrected incident facts and correction notifications appear through the existing tracking/updates flow.

## Traffic enforcer response

Choose Traffic enforcer during account creation and search the shared Philippine police-station directory by name or address. The selected station is saved with the account; Admin approval is still required for police Officer access. Enforcer sign-in uses the saved station and activates duty without asking for a station again. Older accounts without a saved station can choose one in the enforcer workspace after login. Retained Officer sessions open that workspace; Public sessions retain public reporting/history. Keep the app active to appear online (30-second heartbeat; offline after 90 seconds). The directory is cached OpenStreetMap geography and is not guaranteed to include every Philippine station; later updates are shared from the Admin map. Affiliation is self-selected, not GPS presence.

This flow requires migration `20261026090000_enforcer_registration_station.sql` and the updated `register-username` Edge Function. Registration requires a current directory station for new enforcer applications; older mobile clients must update before creating an enforcer account.

Admins assign a selected verified Existing report through its police-station card. My cases offers incident details, a read-only scene map, evidence and versioned progress/official remarks; Verify offers only eligible unassigned cases. Findings/actions use the existing remarks/history rather than new statuses or structured fields. Scene map tiles need internet. The development migration is `20261020090000_enforcer_stations.sql`; apply all migrations on other environments before using this feature. No background push or external emergency dispatch is implied.
