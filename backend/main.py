"""
Main FastAPI application for Misinformation Detection & Education App
Provides serverless APIs for claim verification, education content, and user management
"""

import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin
from firebase_admin import credentials, auth
from google.cloud import firestore, storage, secretmanager
import structlog

# Import routers
from routers import claims, education, users, analytics

# Initialize structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Global variables for Google Cloud clients
firestore_client = None
storage_client = None
secret_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and cleanup resources"""
    global firestore_client, storage_client, secret_client
    
    try:
        # Initialize Firebase Admin SDK
        if not firebase_admin._apps:
            # In production, use service account key from Secret Manager
            if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
                cred = credentials.ApplicationDefault()
            else:
                # For local development
                cred = credentials.Certificate("path/to/serviceAccountKey.json")
            
            firebase_admin.initialize_app(cred, {
                'projectId': os.getenv("GOOGLE_CLOUD_PROJECT", "your-project-id"),
                'storageBucket': os.getenv("STORAGE_BUCKET", "your-project-id.appspot.com")
            })
        
        # Initialize Google Cloud clients
        firestore_client = firestore.Client()
        storage_client = storage.Client()
        secret_client = secretmanager.SecretManagerServiceClient()
        
        logger.info("Application startup complete")
        yield
        
    except Exception as e:
        logger.error("Failed to initialize application", error=str(e))
        raise
    finally:
        # Cleanup resources
        logger.info("Application shutdown complete")


# Create FastAPI app
app = FastAPI(
    title="Misinformation Detection & Education API",
    description="AI-powered APIs for detecting misinformation and providing educational content",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan
)

# Security
security = HTTPBearer()

# Middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://your-app.web.app",
        "https://your-app.firebaseapp.com",
        "http://localhost:3000",  # Flutter web dev
        "http://localhost:8080",  # Flutter web dev
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(
    TrustedHostMiddleware, 
    allowed_hosts=["*"]  # Configure for production
)


# Authentication dependency
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify Firebase ID token and return user info"""
    try:
        # Verify the Firebase ID token
        decoded_token = auth.verify_id_token(credentials.credentials)
        user_id = decoded_token.get('uid')
        user_email = decoded_token.get('email', '')
        
        return {
            "uid": user_id,
            "email": user_email,
            "email_verified": decoded_token.get('email_verified', False),
            "auth_time": decoded_token.get('auth_time'),
            "firebase_claims": decoded_token
        }
    except Exception as e:
        logger.error("Authentication failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


# Health check endpoint
@app.get("/api/health")
async def health_check():
    """Health check endpoint for Cloud Run"""
    return {
        "status": "healthy",
        "service": "misinformation-detection-api",
        "version": "1.0.0"
    }


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Misinformation Detection & Education API",
        "version": "1.0.0",
        "docs": "/api/docs",
        "health": "/api/health"
    }


# Include routers
app.include_router(
    claims.router,
    prefix="/api/claims",
    tags=["Claims Verification"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    education.router,
    prefix="/api/education",
    tags=["Education Content"]
)

app.include_router(
    users.router,
    prefix="/api/users",
    tags=["User Management"],
    dependencies=[Depends(get_current_user)]
)

app.include_router(
    analytics.router,
    prefix="/api/analytics",
    tags=["Analytics & Reporting"],
    dependencies=[Depends(get_current_user)]
)


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler with logging"""
    logger.error(
        "Unhandled exception",
        path=request.url.path,
        method=request.method,
        error=str(exc),
        exc_info=True
    )
    return HTTPException(
        status_code=500,
        detail="Internal server error"
    )


if __name__ == "__main__":
    import uvicorn
    
    # For local development
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8080)),
        reload=True,
        log_level="info"
    )