"""
Education Content Router
Handles educational resources, learning modules, and fact-checking guides
"""

from typing import List, Dict, Optional
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from google.cloud import firestore
import structlog

logger = structlog.get_logger()
router = APIRouter()


class EducationContent(BaseModel):
    """Education content model"""
    id: str = Field(..., description="Unique content identifier")
    title: str = Field(..., description="Content title")
    description: str = Field(..., description="Content description")
    content_type: str = Field(..., description="Type: article, video, quiz, infographic")
    category: str = Field(..., description="Category: media_literacy, fact_checking, etc.")
    language: str = Field("en", description="Content language")
    difficulty_level: str = Field(..., description="Difficulty: beginner, intermediate, advanced")
    duration_minutes: Optional[int] = Field(None, description="Estimated reading/viewing time")
    tags: List[str] = Field(default_factory=list, description="Content tags")
    content_url: Optional[str] = Field(None, description="External content URL")
    thumbnail_url: Optional[str] = Field(None, description="Thumbnail image URL")
    is_featured: bool = Field(False, description="Whether content is featured")
    created_at: str = Field(..., description="Creation timestamp")
    updated_at: str = Field(..., description="Last update timestamp")


class LearningModule(BaseModel):
    """Learning module with lessons"""
    id: str = Field(..., description="Module ID")
    title: str = Field(..., description="Module title")
    description: str = Field(..., description="Module description")
    lessons: List[Dict] = Field(..., description="List of lessons in module")
    total_duration: int = Field(..., description="Total duration in minutes")
    completion_rate: Optional[float] = Field(None, description="User completion rate")


@router.get("/getEducationContent", response_model=List[EducationContent])
async def get_education_content(
    category: Optional[str] = Query(None, description="Filter by category"),
    language: str = Query("en", description="Content language"),
    difficulty: Optional[str] = Query(None, description="Filter by difficulty level"),
    content_type: Optional[str] = Query(None, description="Filter by content type"),
    featured_only: bool = Query(False, description="Show only featured content"),
    limit: int = Query(20, ge=1, le=100, description="Number of items to return"),
    offset: int = Query(0, ge=0, description="Number of items to skip")
):
    """
    Get educational content with filtering options
    Returns curated learning resources about media literacy and fact-checking
    """
    try:
        db = firestore.Client()
        
        # Build query
        query = db.collection("education_content")
        
        # Apply filters
        if category:
            query = query.where("category", "==", category)
        if language:
            query = query.where("language", "==", language)
        if difficulty:
            query = query.where("difficulty_level", "==", difficulty)
        if content_type:
            query = query.where("content_type", "==", content_type)
        if featured_only:
            query = query.where("is_featured", "==", True)
        
        # Order and paginate
        query = query.order_by("created_at", direction=firestore.Query.DESCENDING)
        query = query.limit(limit).offset(offset)
        
        # Execute query
        content_list = []
        for doc in query.stream():
            content_data = doc.to_dict()
            content_list.append(EducationContent(**content_data))
        
        logger.info("Education content retrieved", 
                   count=len(content_list), 
                   category=category, 
                   language=language)
        
        return content_list
        
    except Exception as e:
        logger.error("Failed to get education content", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve education content")


@router.get("/modules", response_model=List[LearningModule])
async def get_learning_modules(
    language: str = Query("en", description="Content language"),
    user_id: Optional[str] = Query(None, description="User ID to get progress")
):
    """Get structured learning modules"""
    try:
        db = firestore.Client()
        
        # Get modules
        modules_query = (
            db.collection("learning_modules")
            .where("language", "==", language)
            .order_by("order", direction=firestore.Query.ASCENDING)
        )
        
        modules = []
        for doc in modules_query.stream():
            module_data = doc.to_dict()
            
            # Get user progress if user_id provided
            if user_id:
                progress_doc = (
                    db.collection("user_progress")
                    .document(f"{user_id}_{doc.id}")
                    .get()
                )
                if progress_doc.exists:
                    progress_data = progress_doc.to_dict()
                    module_data["completion_rate"] = progress_data.get("completion_rate", 0.0)
            
            modules.append(LearningModule(**module_data))
        
        return modules
        
    except Exception as e:
        logger.error("Failed to get learning modules", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve learning modules")


@router.get("/trending-topics")
async def get_trending_topics(
    language: str = Query("en", description="Content language"),
    limit: int = Query(10, description="Number of topics to return")
):
    """Get trending misinformation topics and counter-content"""
    try:
        db = firestore.Client()
        
        # Get trending topics from BigQuery analytics
        # This would typically query BigQuery for trending patterns
        trending_query = (
            db.collection("trending_topics")
            .where("language", "==", language)
            .order_by("trend_score", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )
        
        topics = []
        for doc in trending_query.stream():
            topic_data = doc.to_dict()
            topics.append({
                "topic": topic_data["topic"],
                "description": topic_data["description"],
                "trend_score": topic_data["trend_score"],
                "fact_check_url": topic_data.get("fact_check_url"),
                "counter_narrative": topic_data.get("counter_narrative"),
                "related_claims": topic_data.get("related_claims", [])
            })
        
        return {"trending_topics": topics}
        
    except Exception as e:
        logger.error("Failed to get trending topics", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve trending topics")


@router.get("/fact-check-sources")
async def get_fact_check_sources(language: str = Query("en")):
    """Get list of trusted fact-checking sources"""
    try:
        # Static list of trusted sources - could be moved to Firestore
        sources = {
            "en": [
                {
                    "name": "FactCheck.org",
                    "description": "A Project of The Annenberg Public Policy Center",
                    "url": "https://factcheck.org",
                    "specialties": ["Politics", "Health", "Science"],
                    "credibility_score": 0.95
                },
                {
                    "name": "Snopes",
                    "description": "Fact-checking website covering urban legends and misinformation",
                    "url": "https://snopes.com",
                    "specialties": ["Urban legends", "Viral content", "Politics"],
                    "credibility_score": 0.92
                },
                {
                    "name": "PolitiFact",
                    "description": "Fact-checking website focused on political claims",
                    "url": "https://politifact.com",
                    "specialties": ["Politics", "Government", "Elections"],
                    "credibility_score": 0.94
                }
            ],
            "hi": [  # Hindi sources
                {
                    "name": "Alt News",
                    "description": "Independent fact-checking website in India",
                    "url": "https://altnews.in",
                    "specialties": ["Politics", "Social media", "Religion"],
                    "credibility_score": 0.93
                },
                {
                    "name": "BOOM",
                    "description": "Fact-checking initiative by BloombergQuint",
                    "url": "https://boomlive.in",
                    "specialties": ["Politics", "Social issues", "Health"],
                    "credibility_score": 0.91
                },
                {
                    "name": "Factly",
                    "description": "Data-driven fact-checking platform",
                    "url": "https://factly.in",
                    "specialties": ["Data verification", "Government claims", "Statistics"],
                    "credibility_score": 0.90
                }
            ]
        }
        
        return {
            "sources": sources.get(language, sources["en"]),
            "total_sources": len(sources.get(language, sources["en"]))
        }
        
    except Exception as e:
        logger.error("Failed to get fact-check sources", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve fact-check sources")


@router.post("/track-progress")
async def track_learning_progress(
    module_id: str,
    lesson_id: str,
    completion_percentage: float,
    time_spent_minutes: int,
    user_id: str = Depends(lambda: "test-user")  # Replace with actual auth
):
    """Track user learning progress"""
    try:
        db = firestore.Client()
        
        progress_data = {
            "user_id": user_id,
            "module_id": module_id,
            "lesson_id": lesson_id,
            "completion_percentage": completion_percentage,
            "time_spent_minutes": time_spent_minutes,
            "last_accessed": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP
        }
        
        # Update progress document
        progress_id = f"{user_id}_{module_id}_{lesson_id}"
        db.collection("learning_progress").document(progress_id).set(progress_data, merge=True)
        
        # Update module-level progress
        module_progress_id = f"{user_id}_{module_id}"
        
        # Calculate overall module completion
        module_lessons = db.collection("learning_modules").document(module_id).get()
        if module_lessons.exists:
            total_lessons = len(module_lessons.to_dict().get("lessons", []))
            
            # Get all lesson progress for this module
            completed_lessons = 0
            for lesson_progress in db.collection("learning_progress").where("user_id", "==", user_id).where("module_id", "==", module_id).stream():
                if lesson_progress.to_dict().get("completion_percentage", 0) >= 100:
                    completed_lessons += 1
            
            module_completion_rate = (completed_lessons / total_lessons) * 100 if total_lessons > 0 else 0
            
            db.collection("user_progress").document(module_progress_id).set({
                "user_id": user_id,
                "module_id": module_id,
                "completion_rate": module_completion_rate,
                "lessons_completed": completed_lessons,
                "total_lessons": total_lessons,
                "updated_at": firestore.SERVER_TIMESTAMP
            }, merge=True)
        
        return {"status": "success", "message": "Progress tracked successfully"}
        
    except Exception as e:
        logger.error("Failed to track progress", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to track learning progress")


@router.get("/quiz/{topic}")
async def get_topic_quiz(topic: str, difficulty: str = "beginner"):
    """Get quiz questions for a specific topic"""
    try:
        db = firestore.Client()
        
        quiz_query = (
            db.collection("quizzes")
            .where("topic", "==", topic)
            .where("difficulty", "==", difficulty)
            .limit(1)
        )
        
        quiz_doc = list(quiz_query.stream())
        if not quiz_doc:
            raise HTTPException(status_code=404, detail="Quiz not found for this topic")
        
        quiz_data = quiz_doc[0].to_dict()
        
        # Remove correct answers from response
        questions = []
        for q in quiz_data.get("questions", []):
            question = {
                "id": q["id"],
                "question": q["question"],
                "options": q["options"],
                "explanation": q.get("explanation", "")
            }
            questions.append(question)
        
        return {
            "quiz_id": quiz_data["id"],
            "topic": quiz_data["topic"],
            "difficulty": quiz_data["difficulty"],
            "questions": questions,
            "total_questions": len(questions)
        }
        
    except Exception as e:
        logger.error("Failed to get quiz", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve quiz")


@router.post("/submit-quiz")
async def submit_quiz_answers(
    quiz_id: str,
    answers: Dict[str, str],  # question_id -> selected_option
    user_id: str = Depends(lambda: "test-user")  # Replace with actual auth
):
    """Submit quiz answers and get results"""
    try:
        db = firestore.Client()
        
        # Get correct answers
        quiz_doc = db.collection("quizzes").document(quiz_id).get()
        if not quiz_doc.exists:
            raise HTTPException(status_code=404, detail="Quiz not found")
        
        quiz_data = quiz_doc.to_dict()
        correct_answers = {q["id"]: q["correct_answer"] for q in quiz_data["questions"]}
        
        # Calculate score
        total_questions = len(correct_answers)
        correct_count = sum(1 for q_id, answer in answers.items() 
                          if correct_answers.get(q_id) == answer)
        score_percentage = (correct_count / total_questions) * 100
        
        # Save quiz result
        result_data = {
            "user_id": user_id,
            "quiz_id": quiz_id,
            "answers": answers,
            "score": score_percentage,
            "correct_answers": correct_count,
            "total_questions": total_questions,
            "completed_at": firestore.SERVER_TIMESTAMP
        }
        
        result_id = f"{user_id}_{quiz_id}_{firestore.SERVER_TIMESTAMP}"
        db.collection("quiz_results").document(result_id).set(result_data)
        
        # Prepare detailed results
        results = []
        for q in quiz_data["questions"]:
            q_id = q["id"]
            user_answer = answers.get(q_id)
            is_correct = user_answer == q["correct_answer"]
            
            results.append({
                "question_id": q_id,
                "question": q["question"],
                "user_answer": user_answer,
                "correct_answer": q["correct_answer"],
                "is_correct": is_correct,
                "explanation": q.get("explanation", "")
            })
        
        return {
            "score": score_percentage,
            "correct_answers": correct_count,
            "total_questions": total_questions,
            "passed": score_percentage >= 70,  # 70% pass threshold
            "detailed_results": results
        }
        
    except Exception as e:
        logger.error("Failed to submit quiz", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to submit quiz")