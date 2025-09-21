# Copilot Instructions for AI Coding Agents

## Project Overview
This is an AI-powered misinformation detection and education app, built with Flutter (Dart) for the frontend and FastAPI (Python) for the backend. The backend leverages Google Cloud services (Firestore, Storage, Vision, Document AI, Pub/Sub, etc.) and Firebase for authentication. The app analyzes user-submitted claims (text/images), verifies them using AI, and provides educational content.

## Architecture & Key Components
- **Frontend (Flutter)**: Located in `lib/`. Uses Provider/Riverpod for state management, GoRouter for navigation, and Supabase for some auth/storage. Key entry: `lib/main.dart`.
- **Backend (FastAPI)**: Located in `backend/`. Main entry: `backend/main.py`. Routers in `backend/routers/` handle claims, education, users, analytics. Services in `backend/services/` encapsulate AI, OCR, harm classification, etc.
- **Cloud Integration**: Uses Google Cloud APIs for storage, document processing, translation, and more. Credentials/config via environment variables and Secret Manager.
- **Authentication**: Firebase Auth (backend), Supabase (frontend). Backend endpoints often require Bearer tokens.

## Developer Workflows
- **Run Flutter App**: `flutter run` (from project root)
- **Install Flutter Dependencies**: `flutter pub get`
- **Run Backend Locally**: `uvicorn backend.main:app --reload --port 8080`
- **Install Backend Dependencies**: `pip install -r backend/requirnments.txt`
- **Run Backend Tests**: `pytest backend/`
- **Run Flutter Tests**: `flutter test`

## Patterns & Conventions
- **Feature Modules**: Frontend code is organized by feature in `lib/features/` (e.g., `analysis`, `education`, `community`).
- **API Services**: Shared API logic in `lib/shared/services/` and backend `services/`.
- **Claim Processing**: Claims submitted via `/api/claims/submitClaim` (text/image). Images are uploaded to GCS, OCR is performed, then AI verifies and classifies harm. Results stored in Firestore and returned via `/api/claims/verifyClaim/{claim_id}`.
- **Background Processing**: Non-high-priority claims are queued via Pub/Sub for async processing.
- **Logging**: Uses `structlog` for structured logging in backend.
- **Testing**: Backend uses `pytest`, frontend uses `flutter test`. Coverage: `flutter test --coverage`.
- **Environment Config**: Use `.env` files for secrets locally. Cloud credentials via Secret Manager in production.

## Integration Points
- **Google Cloud**: Firestore, Storage, Vision, Document AI, Pub/Sub, Translate, etc. See `backend/requirnments.txt` for all dependencies.
- **Firebase**: Auth for backend, some storage for frontend.
- **Supabase**: Used in frontend for auth/storage (see `lib/main.dart`).

## Project-Specific Tips
- **Image OCR**: Use `OCRService` in `backend/services/ocr_servlce.py` for extracting text from images. Document AI is used for structured docs if configured.
- **Claim Verification**: See `backend/routers/claims.py` for full claim processing pipeline and async task handling.
- **Frontend Navigation**: All routes are defined in `lib/main.dart` using GoRouter and constants from `lib/core/constants/app_constants.dart`.
- **Error Handling**: Backend uses global exception handler with structured logging. Frontend uses error screens and navigation fallback.

## Example API Flow
1. User submits claim (text/image) via frontend.
2. Backend stores claim, uploads image, performs OCR, verifies claim using AI, classifies harm, and stores results.
3. User fetches verification result via `/api/claims/verifyClaim/{claim_id}`.

## Key Files & Directories
- `lib/main.dart`: Flutter app entry, navigation, theme setup.
- `backend/main.py`: FastAPI app entry, router inclusion, middleware.
- `backend/routers/claims.py`: Claim submission, verification, history.
- `backend/services/ocr_servlce.py`: OCR and Document AI integration.
- `backend/requirnments.txt`: Backend dependencies.
- `README.md`: High-level project overview and setup.

---
**For questions or unclear conventions, check `README.md` or ask the team.**
