"""
Users Router
Handles user profile management and verification history
"""

from typing import List, Dict, Optional
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from google.cloud import firestore
import structlog

logger = structlog.get_logger()
router = APIRouter()


class UserProfile(BaseModel):
    """User profile model"""
    uid: str = Field(..., description="User ID")
    email: str = Field(..., description="User email")
    display_name: Optional[str] = Field(None, description="User display name")
    photo_url: Optional[str] = Field(None, description="Profile photo URL")
    preferred_language: str = Field("en", description="User's preferred language")
    notification_preferences: Dict = Field(default_factory=dict, description="Notification settings")
    verification_stats: Dict = Field(default_factory=dict, description="User verification statistics")
    learning_progress: Dict = Field(default_factory=dict, description="Learning module progress")
    badges: List[str] = Field(default_factory=list, description="Earned achievement badges")
    created_at: datetime = Field(..., description="Account creation timestamp")
    last_active: datetime = Field(..., description="Last activity timestamp")


class UserStats(BaseModel):
    """User statistics model"""
    total_verifications: int = Field(0, description="Total claims verified")
    accuracy_rate: float = Field(0.0, description="Accuracy in identifying false claims")
    learning_modules_completed: int = Field(0, description="Completed learning modules")
    quiz_scores_avg: float = Field(0.0, description="Average quiz score")
    streak_days: int = Field(0, description="Daily usage streak")
    badges_earned: int = Field(0, description="Total badges earned")
    community_contributions: int = Field(0, description="Community reports submitted")


@router.get("/profile", response_model=UserProfile)
async def get_user_profile(user = Depends(lambda: {"uid": "test-user", "email": "test@example.com"})):
    """Get user profile information"""
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        # Get user profile from Firestore
        profile_doc = db.collection("users").document(user_id).get()
        
        if profile_doc.exists:
            profile_data = profile_doc.to_dict()
        else:
            # Create new profile if doesn't exist
            profile_data = {
                "uid": user_id,
                "email": user["email"],
                "display_name": user.get("display_name"),
                "photo_url": user.get("photo_url"),
                "preferred_language": "en",
                "notification_preferences": {
                    "email_notifications": True,
                    "push_notifications": True,
                    "trending_alerts": True,
                    "learning_reminders": True
                },
                "verification_stats": {},
                "learning_progress": {},
                "badges": [],
                "created_at": datetime.now(timezone.utc),
                "last_active": datetime.now(timezone.utc)
            }
            
            # Save new profile
            db.collection("users").document(user_id).set(profile_data)
        
        # Update last active timestamp
        db.collection("users").document(user_id).update({
            "last_active": datetime.now(timezone.utc)
        })
        
        return UserProfile(**profile_data)
        
    except Exception as e:
        logger.error("Failed to get user profile", user_id=user["uid"], error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve user profile")


@router.put("/profile")
async def update_user_profile(
    display_name: Optional[str] = None,
    preferred_language: Optional[str] = None,
    notification_preferences: Optional[Dict] = None,
    user = Depends(lambda: {"uid": "test-user"})
):
    """Update user profile information"""
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        update_data = {"updated_at": datetime.now(timezone.utc)}
        
        if display_name is not None:
            update_data["display_name"] = display_name
        if preferred_language is not None:
            update_data["preferred_language"] = preferred_language
        if notification_preferences is not None:
            update_data["notification_preferences"] = notification_preferences
        
        # Update profile
        db.collection("users").document(user_id).update(update_data)
        
        logger.info("User profile updated", user_id=user_id, fields=list(update_data.keys()))
        
        return {"status": "success", "message": "Profile updated successfully"}
        
    except Exception as e:
        logger.error("Failed to update user profile", user_id=user["uid"], error=str(e))
        raise HTTPException(status_code=500, detail="Failed to update profile")


@router.get("/userHistory", response_model=Dict)
async def get_user_history(
    limit: int = 50,
    offset: int = 0,
    status_filter: Optional[str] = None,
    user = Depends(lambda: {"uid": "test-user"})
):
    """
    Get user's verification history with filtering options
    Returns paginated list of user's claim verifications
    """
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        # Build query for user's claims
        query = db.collection("claims").where("user_id", "==", user_id)
        
        if status_filter:
            query = query.where("status", "==", status_filter)
        
        # Order by submission date (most recent first)
        query = query.order_by("submitted_at", direction=firestore.Query.DESCENDING)
        query = query.limit(limit).offset(offset)
        
        # Execute query
        claims = []
        for doc in query.stream():
            claim_data = doc.to_dict()
            
            # Get verification details if available
            verification_data = {}
            if claim_data["status"] == "completed":
                verification_doc = db.collection("verifications").document(claim_data["claim_id"]).get()
                if verification_doc.exists:
                    verification_data = verification_doc.to_dict()
            
            claim_summary = {
                "claim_id": claim_data["claim_id"],
                "text": claim_data.get("text", "")[:150] + "..." if claim_data.get("text", "") else None,
                "image_url": claim_data.get("image_url"),
                "source_url": claim_data.get("source_url"),
                "status": claim_data["status"],
                "submitted_at": claim_data["submitted_at"],
                "verdict": verification_data.get("verdict"),
                "confidence_score": verification_data.get("confidence_score"),
                "harm_level": verification_data.get("harm_level"),
                "processing_time": None
            }
            
            # Calculate processing time if completed
            if claim_data["status"] == "completed" and verification_data.get("processed_at"):
                submitted = claim_data["submitted_at"]
                processed = verification_data["processed_at"]
                if isinstance(submitted, str):
                    submitted = datetime.fromisoformat(submitted.replace('Z', '+00:00'))
                if isinstance(processed, str):
                    processed = datetime.fromisoformat(processed.replace('Z', '+00:00'))
                
                processing_time = (processed - submitted).total_seconds()
                claim_summary["processing_time"] = processing_time
            
            claims.append(claim_summary)
        
        # Get additional statistics
        stats = await calculate_user_stats(user_id, db)
        
        return {
            "claims": claims,
            "pagination": {
                "total": len(claims),
                "limit": limit,
                "offset": offset,
                "has_more": len(claims) == limit
            },
            "stats": stats
        }
        
    except Exception as e:
        logger.error("Failed to get user history", user_id=user["uid"], error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve user history")


@router.get("/stats", response_model=UserStats)
async def get_user_stats(user = Depends(lambda: {"uid": "test-user"})):
    """Get comprehensive user statistics"""
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        stats = await calculate_user_stats(user_id, db)
        
        return UserStats(**stats)
        
    except Exception as e:
        logger.error("Failed to get user stats", user_id=user["uid"], error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve user statistics")


@router.get("/badges")
async def get_user_badges(user = Depends(lambda: {"uid": "test-user"})):
    """Get user's earned badges and available achievements"""
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        # Get user profile to check earned badges
        profile_doc = db.collection("users").document(user_id).get()
        earned_badges = profile_doc.to_dict().get("badges", []) if profile_doc.exists else []
        
        # Define available badges
        available_badges = [
            {
                "id": "first_verification",
                "name": "First Steps",
                "description": "Complete your first claim verification",
                "icon": "🎯",
                "earned": "first_verification" in earned_badges
            },
            {
                "id": "accurate_detector",
                "name": "Sharp Eye",
                "description": "Achieve 80% accuracy in identifying false claims",
                "icon": "👁️",
                "earned": "accurate_detector" in earned_badges
            },
            {
                "id": "learning_enthusiast",
                "name": "Knowledge Seeker",
                "description": "Complete 5 learning modules",
                "icon": "📚",
                "earned": "learning_enthusiast" in earned_badges
            },
            {
                "id": "community_helper",
                "name": "Community Guardian",
                "description": "Report 10 suspicious claims to the community",
                "icon": "🛡️",
                "earned": "community_helper" in earned_badges
            },
            {
                "id": "streak_master",
                "name": "Consistency Champion",
                "description": "Maintain a 30-day verification streak",
                "icon": "⚡",
                "earned": "streak_master" in earned_badges
            },
            {
                "id": "quiz_expert",
                "name": "Quiz Master",
                "description": "Score 90% or higher on 10 quizzes",
                "icon": "🎓",
                "earned": "quiz_expert" in earned_badges
            }
        ]
        
        return {
            "earned_badges": [badge for badge in available_badges if badge["earned"]],
            "available_badges": available_badges,
            "total_earned": len(earned_badges),
            "total_available": len(available_badges)
        }
        
    except Exception as e:
        logger.error("Failed to get user badges", user_id=user["uid"], error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve badges")


@router.post("/report-claim")
async def report_claim(
    claim_id: str,
    reason: str,
    additional_info: Optional[str] = None,
    user = Depends(lambda: {"uid": "test-user"})
):
    """Report a suspicious or problematic claim"""
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        # Verify claim exists
        claim_doc = db.collection("claims").document(claim_id).get()
        if not claim_doc.exists:
            raise HTTPException(status_code=404, detail="Claim not found")
        
        # Create report
        report_data = {
            "claim_id": claim_id,
            "reporter_id": user_id,
            "reason": reason,
            "additional_info": additional_info,
            "status": "pending",
            "reported_at": datetime.now(timezone.utc)
        }
        
        # Save report
        report_id = f"{user_id}_{claim_id}_{int(datetime.now().timestamp())}"
        db.collection("claim_reports").document(report_id).set(report_data)
        
        # Update user's community contribution count
        user_doc = db.collection("users").document(user_id).get()
        if user_doc.exists:
            current_contributions = user_doc.to_dict().get("community_contributions", 0)
            db.collection("users").document(user_id).update({
                "community_contributions": current_contributions + 1
            })
        
        logger.info("Claim reported", claim_id=claim_id, reporter_id=user_id, reason=reason)
        
        return {"status": "success", "message": "Claim reported successfully", "report_id": report_id}
        
    except Exception as e:
        logger.error("Failed to report claim", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to report claim")


@router.delete("/delete-account")
async def delete_user_account(user = Depends(lambda: {"uid": "test-user"})):
    """Delete user account and all associated data"""
    try:
        db = firestore.Client()
        user_id = user["uid"]
        
        # Delete user's claims
        claims_query = db.collection("claims").where("user_id", "==", user_id)
        for doc in claims_query.stream():
            doc.reference.delete()
        
        # Delete user's verifications
        verifications_query = db.collection("verifications").where("user_id", "==", user_id)
        for doc in verifications_query.stream():
            doc.reference.delete()
        
        # Delete learning progress
        progress_query = db.collection("learning_progress").where("user_id", "==", user_id)
        for doc in progress_query.stream():
            doc.reference.delete()
        
        # Delete user progress
        user_progress_query = db.collection("user_progress").where("user_id", "==", user_id)
        for doc in user_progress_query.stream():
            doc.reference.delete()
        
        # Delete quiz results
        quiz_results_query = db.collection("quiz_results").where("user_id", "==", user_id)
        for doc in quiz_results_query.stream():
            doc.reference.delete()
        
        # Delete user profile
        db.collection("users").document(user_id).delete()
        
        logger.info("User account deleted", user_id=user_id)
        
        return {"status": "success", "message": "Account deleted successfully"}
        
    except Exception as e:
        logger.error("Failed to delete account", user_id=user["uid"], error=str(e))
        raise HTTPException(status_code=500, detail="Failed to delete account")


# Helper functions

async def calculate_user_stats(user_id: str, db) -> Dict:
    """Calculate comprehensive user statistics"""
    try:
        stats = {
            "total_verifications": 0,
            "accuracy_rate": 0.0,
            "learning_modules_completed": 0,
            "quiz_scores_avg": 0.0,
            "streak_days": 0,
            "badges_earned": 0,
            "community_contributions": 0
        }
        
        # Count total verifications
        claims_query = db.collection("claims").where("user_id", "==", user_id)
        total_claims = len(list(claims_query.stream()))
        stats["total_verifications"] = total_claims
        
        # Get user profile data
        profile_doc = db.collection("users").document(user_id).get()
        if profile_doc.exists:
            profile_data = profile_doc.to_dict()
            stats["badges_earned"] = len(profile_data.get("badges", []))
            stats["community_contributions"] = profile_data.get("community_contributions", 0)
        
        # Calculate learning progress
        progress_query = db.collection("user_progress").where("user_id", "==", user_id)
        completed_modules = 0
        for doc in progress_query.stream():
            progress = doc.to_dict()
            if progress.get("completion_rate", 0) >= 100:
                completed_modules += 1
        stats["learning_modules_completed"] = completed_modules
        
        # Calculate average quiz scores
        quiz_results = db.collection("quiz_results").where("user_id", "==", user_id)
        quiz_scores = [doc.to_dict().get("score", 0) for doc in quiz_results.stream()]
        if quiz_scores:
            stats["quiz_scores_avg"] = sum(quiz_scores) / len(quiz_scores)
        
        # Calculate streak (simplified - would need more complex logic for real streaks)
        if total_claims > 0:
            # Check daily activity in last 30 days
            thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)
            recent_claims = (
                db.collection("claims")
                .where("user_id", "==", user_id)
                .where("submitted_at", ">=", thirty_days_ago)
                .order_by("submitted_at", direction=firestore.Query.DESCENDING)
            )
            
            recent_count = len(list(recent_claims.stream()))
            stats["streak_days"] = min(recent_count, 30)  # Simplified calculation
        
        # Calculate accuracy rate (would need ground truth data in real implementation)
        # For now, use a placeholder calculation based on user engagement
        if total_claims > 0:
            completed_verifications = len([
                doc for doc in db.collection("claims").where("user_id", "==", user_id).stream()
                if doc.to_dict().get("status") == "completed"
            ])
            stats["accuracy_rate"] = min(0.95, 0.6 + (completed_verifications / total_claims) * 0.35)
        
        return stats
        
    except Exception as e:
        logger.error("Failed to calculate user stats", user_id=user_id, error=str(e))
        return stats  # Return default stats on error