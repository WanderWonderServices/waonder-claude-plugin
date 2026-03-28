# Milestone 10: Authentication Flow

**Status:** Not Started
**Dependencies:** Milestones 05, 07
**Android Modules:** `:feature:session`, auth data sources, Firebase Auth
**iOS Targets:** `FeatureSession`, `CoreDataLayer` (auth section)

---

## Objective

Implement the complete authentication flow: Firebase Phone Auth (OTP), session management, token lifecycle, and auth state observation.

---

## Deliverables

### 1. Firebase Auth Integration
- [ ] Configure Firebase Auth in iOS project
- [ ] Phone number authentication with OTP
- [ ] Token management (ID token, refresh token)
- [ ] Session persistence across app launches

### 2. FeatureSession (`FeatureSession/`)
- [ ] `SessionViewModel.swift` — mirrors `SessionViewModel.kt`
  - Manages login/logout state transitions
  - Observes auth state from repository
  - Triggers session cleanup on logout

### 3. Auth Data Sources (in `CoreDataLayer/Auth/`)
Already defined in Milestone 07, but implementation happens here:
- [ ] `FirebaseAuthRepositoryImpl.swift` — Full Firebase Auth implementation
  - `sendOtp(phone:)` → Firebase `verifyPhoneNumber`
  - `verifyOtp(code:)` → Firebase `signIn(with: credential)`
  - `logout()` → Firebase `signOut()`
  - `observeAuthState()` → Firebase `addStateDidChangeListener`
- [ ] `SessionRepositoryImpl.swift` — Session state management
- [ ] `TokenAuthenticator.swift` — Auto-refresh tokens on 401

### 4. Session Management (in `CoreDomain`)
Already defined in Milestone 04, validate:
- [ ] `SessionManagerImpl` correctly coordinates auth state
- [ ] `SessionCleanupOrchestrator` clears all caches on logout
- [ ] `SessionState` transitions match Android

---

## Auth Flow (Must Match Android)

```
1. User enters phone number
2. App calls Firebase verifyPhoneNumber → sends OTP
3. User enters 6-digit OTP code
4. App calls Firebase signIn(with: PhoneAuthCredential)
5. On success: Firebase provides ID token
6. ID token stored securely
7. All API requests include token via AuthTokenInterceptor
8. On token expiry (401): TokenAuthenticator refreshes
9. On logout: SessionCleanupOrchestrator clears all data
```

### iOS-Specific Considerations

| Aspect | Android | iOS |
|--------|---------|-----|
| OTP auto-fill | SMS Retriever API | iOS auto-fills OTP from Messages |
| Token storage | EncryptedSharedPreferences | Keychain |
| Background token refresh | OkHttp Authenticator | URLSession delegate |
| Auth state listener | Firebase addAuthStateListener | Firebase addStateDidChangeListener |

---

## Verification

- [ ] User can send OTP to phone number
- [ ] User can verify OTP and sign in
- [ ] Auth state persists across app launches
- [ ] API requests include valid auth token
- [ ] 401 responses trigger token refresh
- [ ] Logout clears all session data
- [ ] Auth state changes propagate to UI immediately
