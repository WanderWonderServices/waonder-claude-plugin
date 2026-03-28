# Milestone 13: Place Details & Chat

**Status:** Not Started
**Dependencies:** Milestones 07, 08, 12
**Android Module:** `:feature:placedetails`
**iOS Target:** `FeaturePlaceDetails`

---

## Objective

Migrate the place details feature — place info card, embedded AI chat, follow-up questions, and related topics. This is a key user-facing feature with real-time messaging.

---

## Deliverables

### 1. Place Details Card (`Components/Card/`)
- [ ] All card composables → SwiftUI views
- [ ] Place name, category, description display
- [ ] Card presentation (bottom sheet / drawer style)
- [ ] Open/close animations

### 2. Chat Feature (`Components/Chat/`)
- [ ] Chat modal view (slides up over card)
- [ ] Message bubble components (user vs AI)
- [ ] Message input field with send button
- [ ] Loading state for AI responses
- [ ] Error state handling
- [ ] Follow-up suggested questions
- [ ] Related topics carousel

### 3. Common Components (`Components/Common/`)
- [ ] Shared components between card and chat

### 4. ViewModels
- [ ] PlaceDetailsViewModel (if separate from chat)
- [ ] ChatViewModel — manages message sending, receiving, state

### 5. Chat Data Flow

```
User types message
  → ChatViewModel.sendMessage()
  → ThreadMessagesRepository.sendMessage()
  → MessageRemoteDataSource (API POST)
  → API processes with AI
  → Poll/stream response
  → Update ChatL1Cache + Room/SwiftData
  → UI recomposes/re-renders
```

### 6. Message Status Tracking
- [ ] Sending → Sent → Failed state machine
- [ ] Retry on failure
- [ ] Optimistic UI (show message immediately, confirm later)

### 7. Related Topics
- [ ] Carousel display of related topics
- [ ] Tap to start new conversation about topic
- [ ] Loaded from `ThreadRelatedTopicsRepository`

---

## Key UI Patterns

### Bottom Sheet / Drawer

Android uses a bottom sheet composable. iOS equivalent:

```swift
// iOS
.sheet(isPresented: $showPlaceDetails) {
    PlaceDetailsView(place: selectedPlace)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

### Chat Scroll Behavior

- New messages scroll to bottom automatically
- User can scroll up to see history
- "Scroll to bottom" button when not at bottom

---

## Verification

- [ ] Place details card shows when tapping annotation on map
- [ ] Card displays correct place information
- [ ] Chat opens from place details
- [ ] User can send messages
- [ ] AI responses appear with correct formatting
- [ ] Message status (sending/sent/failed) displays correctly
- [ ] Follow-up questions are tappable
- [ ] Related topics carousel works
- [ ] Messages persist in local DB
- [ ] Chat history loads for returning to same place
