# war

A new Flutter project.

## Firebase Authentication

The app uses Firebase Authentication for email/password account creation,
Google sign-in, and sign-out. In the Firebase console for this project, enable
**Email/Password** and **Google** under **Authentication → Sign-in method**.
The Firebase app options are configured in `lib/firebase_options.dart`.

### Google sign-in setup

- **Android:** Add your app's SHA-1 and SHA-256 signing certificate
  fingerprints in **Project settings → Your apps → Android app**. For the
  local debug fingerprints, run `android\gradlew signingReport` from the
  project directory. Download the updated `google-services.json` and replace
  `android/app/google-services.json`; it must include a web OAuth client.
- **iOS/macOS:** Follow the Google Sign-In iOS/macOS setup to add the OAuth
  client ID and reversed client ID URL scheme from your
  `GoogleService-Info.plist` to the platform's `Info.plist`. macOS also
  requires the Google Sign-In keychain entitlement.
- **Web:** Add the app's deployment domain under **Authentication → Settings →
  Authorized domains** in Firebase. Google sign-in uses Firebase's popup flow.

Google sign-in is available on Android, iOS, macOS, and web. It is not
supported on Windows or Linux by the configured Google Sign-In plugin.

## Product wallet storage

Products are saved in Cloud Firestore at
`users/{uid}/products/{productId}`. Product photos and warranty sheets are
uploaded to Firebase Storage under that user's product folder; the Firestore
record stores their download URLs. A signed-in user can only access their own
product records and files according to `firestore.rules` and `storage.rules`.

Enable **Cloud Firestore** and **Firebase Storage** for the project, then deploy
the included security rules with
`firebase deploy --only firestore:rules,storage --project warrantywallet-1d409`.
The Firebase Storage bucket must be enabled in the Firebase console before
uploads will work.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
