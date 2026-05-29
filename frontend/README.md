# CaterPro Flutter Frontend

Flutter frontend scaffolded from `stitch_caterpro_manager_ui` screens and the PRS source folder.

## Implemented UI

- Dashboard KPIs, revenue chart, upcoming events, FAB, bottom navigation
- Events list with chips, status badges, amount/balance cards
- Clients list and profile-style cards
- Billing and invoices
- Settings groups
- Create Event wizard with Details, Dates, Menu, and Review steps
- Event Details
- Menu Master
- Business Profile with logo/signature/QR upload placeholders, legal, contact, bank, and terms sections
- Record Payment bottom sheet from Billing and Event Details
- Navigation wiring between Events, Details, Settings, Menu Master, Business Profile, and Create Event

The visual system follows the Stitch design tokens: Quicksand, navy/amber palette, 16dp margins, rounded 12dp cards, MD3-style controls, and mobile-first spacing.

## Run

Install Flutter, then from this folder:

```powershell
flutter pub get
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

If you want Flutter to regenerate complete native wrapper files for the current SDK version without changing `lib/`:

```powershell
flutter create --platforms=android,ios,web .
flutter pub get
```

## Backend Integration Later

The app currently uses static mock data matching the provided screens. When the backend is ready, replace the inline sample data in `lib/main.dart` with repository/service calls and keep the widgets intact.
