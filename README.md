Meet Sync Pro - Flutter Scheduling App
<div align="center">
Meet Sync Pro
A cross-platform mobile scheduling application built with Flutter, featuring real-time conflict detection and smart booking rules.

https://img.shields.io/badge/Download-APK-00C853?style=for-the-badge&logo=android&logoColor=white
https://img.shields.io/badge/Repository-GitHub-181717?style=for-the-badge&logo=github&logoColor=white


https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat-square&logo=flutter&logoColor=white
https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white
https://img.shields.io/badge/Django-4.0+-092E20?style=flat-square&logo=django&logoColor=white
https://img.shields.io/badge/Firebase-9.0+-FFCA28?style=flat-square&logo=firebase&logoColor=black
https://img.shields.io/badge/PostgreSQL-336791?style=flat-square&logo=postgresql&logoColor=white
https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white
https://img.shields.io/badge/Stripe-008CDD?style=flat-square&logo=stripe&logoColor=white
https://img.shields.io/badge/PayPal-00457C?style=flat-square&logo=paypal&logoColor=white

</div>
Table of Contents
Overview

Download App

Features

Tech Stack

System Architecture

Getting Started

Environment Variables

Project Structure

Contact

Overview
Meet Sync Pro is a cross-platform mobile scheduling application built for both iOS and Android. It enables users to schedule meetings with real-time conflict detection, automatic timezone conversion, and smart booking rules. The platform reduces scheduling conflicts by 70% and cuts booking confirmation time through automated multi-timezone workflows.

The application serves hosts and guests with a seamless booking experience, integrating with Google Calendar and providing subscription-based payment processing.

Download App
Platform	Version	Download Link
Android APK	v1.0.0	Download base.apk
Installation Instructions
Download the APK file from the link above

On your Android device, go to Settings → Security → Enable "Install from unknown sources"

Open the downloaded APK file and tap Install

Launch the app and create your account

Note: This APK is for Android devices only. iOS users can build from source.

Features
Core Functionality
User Authentication — Google Sign-In and Email/Password registration

Real-time Scheduling — Smart booking with conflict detection

Multi-timezone Support — Automatic timezone conversion for global meetings

Calendar Integration — Sync with Google Calendar

Payment Processing — Subscription management with Stripe/PayPal

Technical Highlights
Cross-platform (iOS & Android) using Flutter

Real-time notifications via Firebase

Secure authentication with Firebase Auth

RESTful API integration with Django backend

Role-based access control (RBAC)

Tech Stack
Layer	Technology
Mobile Framework	https://img.shields.io/badge/-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white Flutter 3.0+ (Dart)
Backend Framework	https://img.shields.io/badge/-Django-092E20?style=flat-square&logo=django&logoColor=white Django 4.0+ / Django REST Framework
Database	https://img.shields.io/badge/-PostgreSQL-336791?style=flat-square&logo=postgresql&logoColor=white PostgreSQL, Firebase Firestore
Authentication	https://img.shields.io/badge/-Firebase%2520Auth-FFCA28?style=flat-square&logo=firebase&logoColor=black Firebase Authentication
Payments	https://img.shields.io/badge/-Stripe-008CDD?style=flat-square&logo=stripe&logoColor=white Stripe, PayPal
State Management	Provider
Containerization	https://img.shields.io/badge/-Docker-2496ED?style=flat-square&logo=docker&logoColor=white Docker
CI/CD	https://img.shields.io/badge/-GitHub%2520Actions-2088FF?style=flat-square&logo=github-actions&logoColor=white GitHub Actions
Deployment	PythonAnywhere
System Architecture
text
┌───────────────────────┐        ┌───────────────────────┐
│   Flutter Mobile App   │        │   Django Backend API   │
│   (iOS / Android)      │───────▶│   (REST Framework)     │
└───────────┬────────────┘        └────────────┬──────────┘
            │                                    │
            │                                    ▼
            │                     ┌─────────────────────────┐
            │                     │    PostgreSQL + Firebase │
            │                     │    (Primary Database)     │
            │                     └─────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────────────────────┐
│                   External Services                       │
├─────────────────┬─────────────────┬─────────────────────┤
│ Google Calendar │   Stripe/PayPal │  Firebase Cloud     │
│ API             │   Payments      │  Messaging          │
└─────────────────┴─────────────────┴─────────────────────┘
Getting Started
Prerequisites
https://img.shields.io/badge/-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white Flutter SDK 3.0+

https://img.shields.io/badge/-Android%2520Studio-3DDC84?style=flat-square&logo=android-studio&logoColor=white Android Studio / VS Code

Android Emulator or physical device

https://img.shields.io/badge/-Git-F05032?style=flat-square&logo=git&logoColor=white Git

Installation
bash
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
The APK will be generated at:

text
build/app/outputs/flutter-apk/app-release.apk
Environment Variables
Create a .env file in the project root (never commit this file):

env
# Firebase Configuration
FIREBASE_API_KEY=your_api_key
FIREBASE_AUTH_DOMAIN=your_auth_domain
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_storage_bucket
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_APP_ID=your_app_id

# Stripe
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key

# PayPal
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_SECRET=your_paypal_secret

# API Configuration
API_BASE_URL=https://your-api-domain.com
Project Structure
text
meetsync_pro/
├── lib/
│   ├── auth/                  # Authentication screens
│   │   ├── login_page.dart
│   │   ├── register_page.dart
│   │   ├── forgot_password_page.dart
│   │   └── google_sign_in_helper.dart
│   ├── booking/               # Booking management
│   │   ├── meeting_requests_page.dart
│   │   ├── guest_meetings_historyPage.dart
│   │   └── booking_lookup_page.dart
│   ├── calendar/              # Calendar integration
│   │   └── calendar_page.dart
│   ├── home/                  # Main screens
│   │   ├── home_page.dart
│   │   ├── CreateMeetingPage.dart
│   │   └── settings_page.dart
│   ├── payments/              # Subscription & payments
│   │   └── subscription_page.dart
│   ├── services/              # API services
│   │   └── calendar_service.dart
│   ├── settings_content/      # Settings pages
│   │   ├── about_page.dart
│   │   ├── edit_profile_page.dart
│   │   ├── help_page.dart
│   │   └── phone_verification_page.dart
│   ├── legal_pages/           # Legal documents
│   │   └── legal_pages.dart
│   ├── firebase_options.dart  # Firebase configuration
│   └── main.dart              # Application entry point
├── android/                   # Android-specific files
├── ios/                       # iOS-specific files
├── assets/                    # Images and assets
│   ├── google_logo.png
│   ├── microsoft_logo.png
│   └── logo.png
├── web/                       # Web-specific files
├── pubspec.yaml               # Flutter dependencies
└── README.md                  # This file
Building for Production
Android APK
bash
# Build a release APK
flutter build apk --release

# Build split APKs (smaller per architecture)
flutter build apk --split-per-abi
The APK will be at build/app/outputs/apk/release/app-release.apk

iOS
bash
# Build for iOS (requires macOS with Xcode)
flutter build ios --release
Contact
Joseph N. Gikuru

Email: gikurujoseph53@gmail.com

LinkedIn: Joseph Gikuru

GitHub: JosephNderitu

License
Distributed under the MIT License. See LICENSE for more information.

Acknowledgments
Flutter - Cross-platform UI framework

Django - Backend framework

Firebase - Authentication and real-time features

Google Calendar API - Calendar integration

<div align="center">
Built with ❤️ by Joseph N. Gikuru

⭐ Star this repository if you find it helpful!

</div>