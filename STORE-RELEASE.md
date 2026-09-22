# TLC Med Clinics — Play Store aur App Store par app bhejne ki checklist

Code wala hissa mukammal hai. Neeche wo kaam hain jo sirf aap kar sakti hain — kyunke un ke liye aap ke accounts, passwords ya ek Mac chahiye. Tarteeb se karein; har qadam agle ke liye zaroori hai.

---

## 0. Sab se pehle (dono platforms)

1. Website deploy karein (Hostinger). Is mein nayi cheezein hain jo app ko chahiye: `/.well-known/assetlinks.json`, `/account-deletion` page, aur coupon wali security fix.
2. Firestore rules deploy karein, agar abhi tak nahi kiye:
   ```
   firebase deploy --only firestore:rules
   ```
3. App folder mein:
   ```
   flutter pub get
   flutter analyze
   ```
   `flutter analyze` mein koi **error** aaye to mujhe bhej dein. Maine teen naye packages add kiye hain (`sign_in_with_apple`, `app_links`, `cryptography`) aur is machine par Flutter nahi tha, is liye code chala kar nahi dekh saki.
4. Asli phone par yeh sab test karein (debug build kaafi hai):
   - Email, phone OTP aur Google se sign-in
   - Booking: coupon lagana aur hatana, card payment (browser mein khulta hai), JazzCash/EasyPaisa
   - Video call join karna — **pehle yeh toota hua tha**, link ghalat banta tha; ab theek hai
   - Chat: patient app se message bhejein, website par doctor ki taraf se parhein, aur ulta bhi — dono taraf padha ja sake
   - Notification: session start karein, lock screen par aaye aur tap karne se appointment khule
   - Language Urdu karein, sab kuch Urdu mein ho
   - Profile → Delete account (ek test account par)

---

## 1. Android — Google Play

### Signing key (sirf ek dafa, aur isay kabhi na khoein)

```
keytool -genkey -v -keystore C:\keys\tlc-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Phir `android/key.properties.example` ko copy kar ke `android/key.properties` banayein aur passwords bharein. **`key.properties` aur `.jks` kabhi git mein commit na karein.** Is key ki backup do jagah rakhein. Yeh kho gayi to app ko kabhi update nahi kiya ja sakega.

### Firebase mein fingerprints

1. SHA-1 aur SHA-256 nikalein:
   ```
   keytool -list -v -keystore C:\keys\tlc-upload-keystore.jks -alias upload
   ```
2. Pehli upload ke baad Play Console → **Setup → App signing** se "App signing key" ka SHA-1 aur SHA-256 bhi lein.
3. Firebase Console → Project settings → Android app `com.tlcmedclinics.tlc_med_clinics` → **dono** keys ke SHA-1 aur SHA-256 add karein.
4. Nayi `google-services.json` download kar ke `android/app/` mein rakh dein.

Play App Signing wali key ke baghair Google sign-in internal testing mein chalega, lekin Play Store se download karne wale har mariz ke liye fail hoga.

### Payment ke baad app mein wapsi (App Links)

Website ki `public/.well-known/assetlinks.json` mein `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` ki jagah Play App Signing ka **SHA-256** paste karein aur site dobara deploy karein. Check:
```
https://tlcmedclinics.com/.well-known/assetlinks.json
```

### Build

```
flutter build appbundle --release
```
File yahan milegi: `build/app/outputs/bundle/release/app-release.aab`

### Play Console ke forms (App content)

| Form | Kya bharna hai |
|---|---|
| Privacy policy | `https://tlcmedclinics.com/privacy` |
| App access | Reviewer ke liye **ek test patient account** ka email aur password (app login ke baghair kuch nahi dikhati; is ke baghair reject hoti hai) |
| Ads | No |
| Content rating | Questionnaire — medical/health app |
| Target audience | 18+ |
| Health apps | Declaration bharein — "Medical", "Telemedicine", "Mental health" |
| Data safety | Neeche wala table |
| Account deletion URL | `https://tlcmedclinics.com/account-deletion` |

**Data safety** — sab "collected", "linked to user", "not shared for advertising", "encrypted in transit", "users can request deletion":

- Personal info: Name, Email, Phone number
- Health and fitness: Health info (appointments, prescriptions)
- Messages: Other in-app messages (doctor chat)
- Financial info: Purchase history (payment records — card number app mein nahi aata)
- App activity / Device IDs: Firebase push token

**Zaroori:** agar aap ka Play developer account **personal** hai (company ka nahi), to Google production se pehle **closed testing mein 12 testers ko 14 din** chalwane ki shart rakhta hai. Is ke liye waqt rakhein. Organization account par yeh shart nahi.

---

## 2. iOS — App Store

### Pehle yeh do cheezein

- **Mac chahiye**, ya [Codemagic](https://codemagic.io) jaisi service jo cloud mein iOS build karti hai. Windows se iOS build nahi hota.
- **Apple Developer account ($99 saal).** Apple ka guideline 5.1.1(ix) kehta hai ke healthcare apps **company / legal entity ke account** se submit hon, kisi individual ke account se nahi. Clinic ke naam se "Organization" account banwayein, jis ke liye D-U-N-S number chahiye hota hai (free, lekin kuch din lagte hain).

### Apple Developer portal (developer.apple.com)

1. Identifiers → App ID `com.tlcmedclinics.tlcMedClinics` → **Push Notifications** aur **Sign in with Apple** on karein.
2. Keys → nayi key banayein, **Apple Push Notifications service (APNs)** tick karein, `.p8` file download karein.

### Firebase

1. Project settings → Cloud Messaging → Apple app → `.p8` APNs key upload karein (Key ID aur Team ID ke saath). Is ke baghair iPhone par koi notification nahi aayegi.
2. Authentication → Sign-in method → **Apple** enable karein.
3. App folder mein:
   ```
   flutterfire configure
   ```
   Yeh `GoogleService-Info.plist` sahi jagah daal dega. Loose file haath se copy na karein.

### Build (Mac par)

```
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

Xcode mein: Runner → Signing & Capabilities → apni Team chunein. Push Notifications aur Sign in with Apple wahan pehle se nazar aane chahiyein (entitlements file add kar di hai). Phir Product → Archive → Distribute → App Store Connect.

### App Store Connect

| Jagah | Kya bharna hai |
|---|---|
| App Privacy | Wahi data jo upar Data safety mein hai. Tracking: **No** |
| Privacy Policy URL | `https://tlcmedclinics.com/privacy` |
| App Review Information | **Demo account** ka email aur password, aur note: "Video consultations open in the device browser; chat and booking are in-app." |
| Age rating | 17+ (medical/treatment information) |
| Export compliance | Plist mein pehle se "No" hai, sawal nahi aayega |

---

## 3. Maine code mein kya kiya (is release ke liye)

**App**

- Account delete karne ka option (Profile ke neeche) — dono stores ki shart
- Sign in with Apple (sirf iPhone par) — Apple ki shart, kyunke Google sign-in maujood hai
- Privacy, Terms aur Refund policy ke links app ke andar, aur sign-up par agreement line
- Doctor aur mariz ka encrypted chat — website wale thread ke saath hi
- Booking mein coupon, New/Follow-up patient, video/audio/chat ka intekhab
- Contact form, aur Information hub (Conditions, Treatments, FAQ, Blog… website par khulte hain)
- Card payment ke baad link app mein wapas le aata hai (Android)
- **Video call ka link fix** — pehle ghalat banta tha
- iOS: app icon (Flutter ka default logo tha, ab clinic ka logo hai), notifications ki entitlement, privacy manifest (`PrivacyInfo.xcprivacy`), Podfile (iOS 13)
- Android: notification icon (pehle status bar mein safed dhabba aata)
- Camera/mic ki permission hata di — app khud camera use nahi karti. Unused permission par Apple sawal karta hai.

**Website**

- `/account-deletion` public page (Play Console ko chahiye), Urdu aur English dono
- `assetlinks.json`
- **Security fix:** coupon check wala API har kisi ko un mariz'on ki email list de raha tha jin ke liye coupon tha. Ab wo list nahi jaati.

---

## 4. Jo abhi baqi hai (release ko nahi rokta)

- iPhone par payment ke baad app mein khud wapsi (Universal Links) — is ke liye Apple Team ID chahiye. Filhal mariz app par wapas aata hai to app khud refresh ho jati hai.
- Services aur blog ka Urdu matan: admin panel → Translations mein bharna hai.
- Legal pages ka English wakeel se check karwana; phir Urdu dobara.
