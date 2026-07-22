<div align="center">

# Meet Sync Pro

**A cross-platform mobile scheduling application built with Flutter, featuring real-time conflict detection and smart booking rules.**

[![Download APK](https://img.shields.io/badge/Download-APK-00C853?style=for-the-badge&logo=android&logoColor=white)](#download-app)
[![Repository](https://img.shields.io/badge/Repository-GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/JosephNderitu/CALENDRY-APP-FLUTTER)

![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![Google OAuth](https://img.shields.io/badge/Google_OAuth_2.0-4285F4?style=flat-square&logo=google&logoColor=white)
![Microsoft OAuth](https://img.shields.io/badge/Microsoft_OAuth_2.0-5E5E5E?style=flat-square&logo=microsoft&logoColor=white)
![Stripe](https://img.shields.io/badge/Stripe-008CDD?style=flat-square&logo=stripe&logoColor=white)
![PayPal](https://img.shields.io/badge/PayPal-00457C?style=flat-square&logo=paypal&logoColor=white)

</div>

## Table of Contents

- [Overview](#overview)
- [Download App](#download-app)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [System Architecture](#system-architecture)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Project Structure](#project-structure)
- [Contact](#contact)

## Overview

Meet Sync Pro is a cross-platform mobile scheduling application built for iOS and Android. It enables users to schedule meetings with real-time conflict detection, automatic timezone conversion, and smart booking rules, reducing scheduling conflicts and cutting booking confirmation time through automated multi-timezone workflows.

The application serves hosts and guests with a seamless booking experience, integrating with Google Calendar and providing subscription-based payment processing.

## Download App

| Platform | Version | Download |
|---|---|---|
| Android APK | v1.0.0 | [Download base.apk](#) |

**Installation Instructions**

1. Download the APK file from the link above.
2. On your Android device, go to **Settings → Security** and enable **Install from unknown sources**.
3. Open the downloaded APK file and tap **Install**.
4. Launch the app and create your account.

> This APK is for Android devices only. iOS users can build from source.

## Features

**Core Functionality**
- User Authentication — OAuth 2.0 sign-in with Google and Microsoft, plus email/password registration
- Real-time Scheduling — smart booking with conflict detection
- Multi-timezone Support — automatic timezone conversion for global meetings
- Calendar Integration — sync with Google Calendar
- Payment Processing — subscription management with Stripe and PayPal

**Technical Highlights**
- Cross-platform (iOS and Android) built with Flutter
- Real-time data sync and notifications via Firebase
- Secure authentication with Firebase Authentication and OAuth 2.0
- Role-based access control (RBAC)

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Framework | ![Flutter](https://img.shields.io/badge/-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white) Flutter 3.0+ (Dart) |
| Backend & Database | ![Firebase](https://img.shields.io/badge/-Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black) Firebase (Firestore, Cloud Functions) |
| Authentication | ![Firebase Auth](https://img.shields.io/badge/-Firebase%20Auth-FFCA28?style=flat-square&logo=firebase&logoColor=black) Firebase Authentication with OAuth 2.0 (Google, Microsoft) |
| Payments | ![Stripe](https://img.shields.io/badge/-Stripe-008CDD?style=flat-square&logo=stripe&logoColor=white) Stripe · ![PayPal](https://img.shields.io/badge/-PayPal-00457C?style=flat-square&logo=paypal&logoColor=white) PayPal |
| State Management | Provider |

## System Architecture

```
┌─────────────────────────┐        ┌──────────────────────────┐
│   Flutter Mobile App    │───────▶│   Firebase Backend        │
│   (iOS / Android)       │        │   (Auth, Firestore,       │
│                          │◀───────│    Cloud Functions)       │
└────────────┬─────────────┘        └─────────────┬──────────┘
             │                                     │
             ▼                                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      External Services                       │
├──────────────────┬──────────────────┬────────────────────────┤
│ Google Calendar   │  Stripe / PayPal │  Google & Microsoft    │
│ API               │  Payments        │  OAuth 2.0 Providers   │
└──────────────────┴──────────────────┴────────────────────────┘
```

## Getting Started

**Prerequisites**
- Flutter SDK 3.0+
- Android Studio or VS Code
- Android Emulator or physical device
- Git

**Installation**

```bash
# Clone the repository
git clone https://github.com/JosephNderitu/CALENDRY-APP-FLUTTER.git

# Navigate to the project directory
cd CALENDRY-APP-FLUTTER/FrontEnd/meetsync_pro

# Install Flutter dependencies
flutter pub get

# Run the app on an emulator or physical device
flutter run

# Build a release APK
flutter build apk --release
```

The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

**Building for Production**

```bash
# Standard release build
flutter build apk --release

# Split APKs by architecture (smaller file size)
flutter build apk --split-per-abi

# iOS build (requires macOS with Xcode)
flutter build ios --release
```

## Environment Variables

Create a `.env` file in the project root (never commit this file):

```env
# Firebase Configuration
FIREBASE_API_KEY=your_api_key
FIREBASE_AUTH_DOMAIN=your_auth_domain
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_storage_bucket
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id

# OAuth 2.0
GOOGLE_OAUTH_CLIENT_ID=your_google_client_id
MICROSOFT_OAUTH_CLIENT_ID=your_microsoft_client_id
MICROSOFT_OAUTH_TENANT_ID=your_microsoft_tenant_id

# Stripe
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key

# PayPal
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_SECRET=your_paypal_secret
```

## Project Structure

```
meetsync_pro/
├── lib/
│   ├── auth/                  # Authentication screens (email, Google, Microsoft)
│   │   ├── login_page.dart
│   │   ├── register_page.dart
│   │   ├── forgot_password_page.dart
│   │   └── google_sign_in_helper.dart
│   ├── booking/               # Booking management
│   │   ├── meeting_requests_page.dart
│   │   ├── guest_meetings_historyPage.dart
│   │   └── booking_lookup_page.dart
│   ├── calendar/               # Calendar integration
│   │   └── calendar_page.dart
│   ├── home/                   # Main screens
│   │   ├── home_page.dart
│   │   ├── CreateMeetingPage.dart
│   │   └── settings_page.dart
│   ├── payments/                # Subscription and payments
│   │   └── subscription_page.dart
│   ├── services/                # API and Firebase services
│   │   └── calendar_service.dart
│   ├── settings_content/        # Settings pages
│   │   ├── about_page.dart
│   │   ├── edit_profile_page.dart
│   │   ├── help_page.dart
│   │   └── phone_verification_page.dart
│   ├── legal_pages/             # Legal documents
│   │   └── legal_pages.dart
│   ├── firebase_options.dart    # Firebase configuration
│   └── main.dart                # Application entry point
├── android/                     # Android-specific files
├── ios/                         # iOS-specific files
├── assets/                      # Images and assets
├── pubspec.yaml                 # Flutter dependencies
└── README.md
```

## Contact

**Joseph N. Gikuru**

- Email: gikurujoseph53@gmail.com
- LinkedIn: [Joseph Gikuru](#)
- GitHub: [JosephNderitu](https://github.com/JosephNderitu)

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

<div align="center">
Built by Joseph N. Gikuru
</div>