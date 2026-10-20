# RoadSafe Mobile

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

Registration now asks only for username and password, with immediate sign-in and no confirmation email. Usernames are case-insensitive and must start with a letter, using 3–24 letters, numbers, or underscores. Existing email-based accounts can still use their original email in the Username sign-in field. Supabase Auth remains responsible for password hashing and sessions; the server creates internal identities without sending email.

## R07 reporter policy

New reports require full name and contact number (1–120 trimmed characters each), plus the existing sign-in. Both fields validate before review. Previously saved reports and their stable-ID retries retain optional legacy identities. Explicit server identity-policy rejections return the updated app to editable contact fields. Older clients submitting blanks are rejected by the new backend policy; update the app or restart the draft with both fields supplied. Admin-corrected incident facts and correction notifications appear through the existing tracking/updates flow.
