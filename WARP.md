# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a Flutter-based mobile application for AI-powered misinformation detection and education. The app analyzes text, links, images, and videos for credibility, provides real-time misinformation alerts, and includes gamified educational modules.

## Common Development Commands

### Build and Run
```bash
# Run the app in debug mode
flutter run

# Run on specific device (list devices first)
flutter devices
flutter run -d <device_id>

# Run in release mode for performance testing
flutter run --release

# Build APK for Android
flutter build apk
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Run integration tests (when available)
flutter test integration_test
```

### Code Quality and Linting
```bash
# Analyze code for issues
flutter analyze

# Format code
dart format .

# Format specific file or directory
dart format lib/features/

# Check for outdated dependencies
flutter pub outdated
```

### Dependency Management
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Clean and rebuild
flutter clean
flutter pub get
```

### Development Utilities
```bash
# Generate app icons (when flutter_launcher_icons is configured)
flutter pub run flutter_launcher_icons

# Check Flutter environment
flutter doctor

# Enable web support (for testing)
flutter config --enable-web

# Create new feature module
mkdir -p lib/features/<feature_name>/{data,domain,presentation}/{models,repositories,screens,widgets}
```

## Architecture Overview

### Core Architecture Pattern
The app follows a **feature-based modular architecture** with clear separation of concerns:

1. **Feature Modules** (`lib/features/`): Each major feature (auth, analysis, alerts, education, community, profile) is isolated in its own module with:
   - `data/`: API clients, data sources, repositories implementation
   - `domain/`: Business logic, entities, repository interfaces
   - `presentation/`: UI screens, widgets, state management

2. **Shared Components** (`lib/shared/`):
   - `widgets/`: Reusable UI components used across features
   - `models/`: Core data models shared between features
   - `services/`: API services, caching, and utility services

3. **Configuration Layer** (`lib/config/`, `lib/core/`):
   - Centralized app configuration (API endpoints, feature flags, limits)
   - Theme definitions with comprehensive Material 3 theming
   - Constants and enums used throughout the app

### State Management Strategy
The app is configured for **Provider** pattern (with potential migration to Riverpod):
- Each feature module will have its own providers
- Global app state managed at the root level
- Local widget state using StatefulWidget where appropriate

### Navigation Architecture
Uses **go_router** for declarative routing:
- Route definitions in `lib/routes/`
- Deep linking support
- Navigation guards for authentication

### Data Flow Architecture
1. **API Layer**: Dio client with interceptors for auth, caching, and error handling
2. **Repository Pattern**: Abstracts data sources from business logic
3. **Caching Strategy**: 
   - SQLite for persistent local storage
   - In-memory caching for session data
   - 7-day cache validity for analysis results

### Authentication Flow
Multi-provider authentication system:
- Firebase Auth for social logins (Google Sign-In)
- Custom JWT for traditional email/password
- Biometric authentication support
- Guest mode for limited access

### Content Analysis Pipeline
1. Content input (text/image/video/link)
2. Validation against size/length limits
3. API submission with progress tracking
4. Result caching and display
5. Community verification layer

### Key Architectural Decisions

1. **Firebase Integration**: Analytics, Crashlytics, and Push Notifications are deeply integrated
2. **Offline-First**: Critical features work offline with sync when connected
3. **Modular Features**: Each feature can be developed/tested independently
4. **Gamification System**: XP and achievement tracking built into core user model
5. **Community Moderation**: Reputation-based system with cooldowns and limits

## API Integration Points

- Base URL: `https://api.truthlens.com/v1`
- Timeout: 30 seconds for connections and responses
- Daily analysis limit: 50 for free users
- Content limits:
  - Text: 5000 characters
  - Images: 10 MB
  - Videos: 50 MB

## Performance Considerations

- Use `const` constructors wherever possible for widget optimization
- Implement lazy loading for lists using ListView.builder
- Cache network images using cached_network_image
- Pagination with 20 items per page (max 100)

## Testing Guidelines

- Widget tests for all custom widgets in `lib/shared/widgets/`
- Integration tests for critical user flows (auth, analysis, reporting)
- Unit tests for business logic in repositories and services
- Mock API responses for testing without backend dependency