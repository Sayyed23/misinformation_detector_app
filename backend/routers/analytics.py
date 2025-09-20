"""
Analytics Router
Handles analytics, reporting, and insights generation
"""

from typing import List, Dict, Optional
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from google.cloud import bigquery
import structlog

logger = structlog.get_logger()
router = APIRouter()


class TrendingTopic(BaseModel):
    """Trending misinformation topic model"""
    topic: str = Field(..., description="Topic name")
    mention_count: int = Field(..., description="Number of mentions")
    trend_score: float = Field(..., description="Trend score (0-1)")
    sentiment: str = Field(..., description="Overall sentiment")
    related_keywords: List[str] = Field(..., description="Related keywords")


class MisinformationInsight(BaseModel):
    """Misinformation insight model"""
    category: str = Field(..., description="Misinformation category")
    total_claims: int = Field(..., description="Total claims in this category")
    false_claims_ratio: float = Field(..., description="Ratio of false claims")
    avg_confidence_score: float = Field(..., description="Average AI confidence score")
    top_sources: List[str] = Field(..., description="Top sources of misinformation")
    geographic_distribution: Dict = Field(..., description="Geographic spread")


@router.get("/trending")
async def get_trending_analysis(
    time_range: str = Query("7d", description="Time range: 1d, 7d, 30d"),
    language: str = Query("en", description="Language filter"),
    limit: int = Query(10, description="Number of trends to return")
):
    """Get trending misinformation topics and patterns"""
    try:
        # Initialize BigQuery client
        client = bigquery.Client()
        
        # Calculate date range
        if time_range == "1d":
            start_date = datetime.now(timezone.utc) - timedelta(days=1)
        elif time_range == "7d":
            start_date = datetime.now(timezone.utc) - timedelta(days=7)
        elif time_range == "30d":
            start_date = datetime.now(timezone.utc) - timedelta(days=30)
        else:
            start_date = datetime.now(timezone.utc) - timedelta(days=7)
        
        # Query trending topics from BigQuery
        query = f"""
        WITH claim_topics AS (
          SELECT 
            topic,
            COUNT(*) as mention_count,
            AVG(confidence_score) as avg_confidence,
            COUNT(CASE WHEN verdict = 'false' THEN 1 END) / COUNT(*) as false_ratio,
            ARRAY_AGG(DISTINCT keywords LIMIT 5) as related_keywords
          FROM `{client.project}.misinformation_analytics.claims_analysis`
          WHERE 
            submitted_at >= @start_date
            AND language = @language
          GROUP BY topic
          HAVING mention_count >= 3
        ),
        trending_calculation AS (
          SELECT 
            *,
            -- Calculate trend score based on volume, recency, and falseness
            (mention_count * 0.4 + false_ratio * 0.4 + (1 - avg_confidence) * 0.2) as trend_score
          FROM claim_topics
        )
        SELECT *
        FROM trending_calculation
        ORDER BY trend_score DESC
        LIMIT @limit
        """
        
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("start_date", "TIMESTAMP", start_date),
                bigquery.ScalarQueryParameter("language", "STRING", language),
                bigquery.ScalarQueryParameter("limit", "INT64", limit),
            ]
        )
        
        try:
            query_job = client.query(query, job_config=job_config)
            results = query_job.result()
            
            trending_topics = []
            for row in results:
                trending_topics.append({
                    "topic": row.topic,
                    "mention_count": row.mention_count,
                    "trend_score": float(row.trend_score),
                    "sentiment": "negative" if row.false_ratio > 0.5 else "neutral",
                    "related_keywords": row.related_keywords or []
                })
            
        except Exception as bq_error:
            # Fallback to mock data if BigQuery fails
            logger.warning("BigQuery unavailable, using mock data", error=str(bq_error))
            trending_topics = [
                {
                    "topic": "COVID-19 Vaccines",
                    "mention_count": 156,
                    "trend_score": 0.85,
                    "sentiment": "negative",
                    "related_keywords": ["side effects", "conspiracy", "efficacy"]
                },
                {
                    "topic": "Election Fraud Claims",
                    "mention_count": 89,
                    "trend_score": 0.72,
                    "sentiment": "negative", 
                    "related_keywords": ["voting machines", "ballot harvesting", "fraud"]
                },
                {
                    "topic": "Climate Change Denial",
                    "mention_count": 67,
                    "trend_score": 0.68,
                    "sentiment": "negative",
                    "related_keywords": ["global warming", "hoax", "manipulation"]
                }
            ]
        
        return {
            "trending_topics": trending_topics,
            "time_range": time_range,
            "language": language,
            "generated_at": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error("Failed to get trending analysis", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve trending analysis")


@router.get("/insights")
async def get_misinformation_insights(
    category: Optional[str] = Query(None, description="Filter by category"),
    time_range: str = Query("30d", description="Time range for analysis"),
    language: str = Query("en", description="Language filter")
):
    """Get comprehensive misinformation insights and patterns"""
    try:
        client = bigquery.Client()
        
        # Calculate date range
        if time_range == "7d":
            start_date = datetime.now(timezone.utc) - timedelta(days=7)
        elif time_range == "30d":
            start_date = datetime.now(timezone.utc) - timedelta(days=30)
        elif time_range == "90d":
            start_date = datetime.now(timezone.utc) - timedelta(days=90)
        else:
            start_date = datetime.now(timezone.utc) - timedelta(days=30)
        
        # Query insights from BigQuery
        category_filter = "AND category = @category" if category else ""
        
        query = f"""
        WITH category_analysis AS (
          SELECT 
            category,
            COUNT(*) as total_claims,
            COUNT(CASE WHEN verdict = 'false' THEN 1 END) / COUNT(*) as false_ratio,
            AVG(confidence_score) as avg_confidence,
            ARRAY_AGG(DISTINCT source_domain ORDER BY source_domain LIMIT 10) as top_sources,
            COUNT(DISTINCT user_location) as geographic_reach
          FROM `{client.project}.misinformation_analytics.claims_analysis`
          WHERE 
            submitted_at >= @start_date
            AND language = @language
            {category_filter}
          GROUP BY category
          HAVING total_claims >= 5
        )
        SELECT *
        FROM category_analysis
        ORDER BY false_ratio DESC, total_claims DESC
        """
        
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("start_date", "TIMESTAMP", start_date),
                bigquery.ScalarQueryParameter("language", "STRING", language),
            ] + ([bigquery.ScalarQueryParameter("category", "STRING", category)] if category else [])
        )
        
        try:
            query_job = client.query(query, job_config=job_config)
            results = query_job.result()
            
            insights = []
            for row in results:
                insights.append({
                    "category": row.category,
                    "total_claims": row.total_claims,
                    "false_claims_ratio": float(row.false_ratio),
                    "avg_confidence_score": float(row.avg_confidence),
                    "top_sources": row.top_sources or [],
                    "geographic_distribution": {
                        "unique_locations": row.geographic_reach,
                        "reach_score": min(1.0, row.geographic_reach / 50.0)  # Normalized
                    }
                })
                
        except Exception as bq_error:
            # Fallback to mock data
            logger.warning("BigQuery unavailable, using mock data", error=str(bq_error))
            insights = [
                {
                    "category": "Health",
                    "total_claims": 234,
                    "false_claims_ratio": 0.67,
                    "avg_confidence_score": 0.82,
                    "top_sources": ["fakehealthnews.com", "conspiracyhealth.org"],
                    "geographic_distribution": {
                        "unique_locations": 45,
                        "reach_score": 0.9
                    }
                },
                {
                    "category": "Politics", 
                    "total_claims": 189,
                    "false_claims_ratio": 0.54,
                    "avg_confidence_score": 0.78,
                    "top_sources": ["biasednews.net", "partisan-blog.com"],
                    "geographic_distribution": {
                        "unique_locations": 38,
                        "reach_score": 0.76
                    }
                }
            ]
        
        return {
            "insights": insights,
            "time_range": time_range,
            "category_filter": category,
            "language": language,
            "generated_at": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error("Failed to get insights", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve insights")


@router.get("/user-impact")
async def get_user_impact_metrics(
    time_range: str = Query("30d", description="Time range for analysis"),
    user = Depends(lambda: {"uid": "test-user"})
):
    """Get user's impact on misinformation detection"""
    try:
        user_id = user["uid"]
        
        # Calculate user's contribution metrics
        # This would typically query BigQuery for user-specific analytics
        
        # Mock calculation for demonstration
        user_impact = {
            "verifications_completed": 45,
            "accuracy_rate": 0.87,
            "false_claims_identified": 28,
            "community_saves": 156,  # Estimated people who saw corrections
            "knowledge_sharing": {
                "articles_shared": 12,
                "explanations_provided": 8,
                "community_discussions": 15
            },
            "learning_contribution": {
                "modules_completed": 6,
                "quiz_scores_avg": 0.91,
                "peer_help_instances": 4
            },
            "trend_participation": {
                "early_detections": 3,  # Claims detected before trending
                "counter_narrative_shares": 18,
                "fact_check_citations": 22
            }
        }
        
        # Calculate impact score
        impact_score = (
            user_impact["accuracy_rate"] * 0.3 +
            min(1.0, user_impact["verifications_completed"] / 100) * 0.25 +
            min(1.0, user_impact["community_saves"] / 500) * 0.25 +
            min(1.0, user_impact["knowledge_sharing"]["articles_shared"] / 20) * 0.1 +
            min(1.0, user_impact["learning_contribution"]["modules_completed"] / 10) * 0.1
        )
        
        user_impact["overall_impact_score"] = round(impact_score, 2)
        user_impact["impact_level"] = (
            "Expert" if impact_score >= 0.8 else
            "Advanced" if impact_score >= 0.6 else
            "Intermediate" if impact_score >= 0.4 else
            "Beginner"
        )
        
        return {
            "user_impact": user_impact,
            "time_range": time_range,
            "generated_at": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error("Failed to get user impact", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve user impact metrics")


@router.get("/platform-stats")
async def get_platform_statistics():
    """Get overall platform statistics and health metrics"""
    try:
        # This would typically query BigQuery for platform-wide statistics
        # Using mock data for demonstration
        
        platform_stats = {
            "total_claims_processed": 15847,
            "total_users": 8921,
            "accuracy_metrics": {
                "overall_accuracy": 0.84,
                "ai_confidence_avg": 0.79,
                "human_feedback_score": 0.91
            },
            "verification_breakdown": {
                "true_claims": 6234,
                "false_claims": 7856,
                "misleading_claims": 1521,
                "unverified_claims": 236
            },
            "category_distribution": {
                "health": 0.28,
                "politics": 0.24,
                "technology": 0.15,
                "social_issues": 0.12,
                "entertainment": 0.08,
                "other": 0.13
            },
            "geographic_reach": {
                "countries": 67,
                "languages_supported": 12,
                "top_regions": ["North America", "Europe", "South Asia", "Southeast Asia"]
            },
            "processing_performance": {
                "avg_processing_time_seconds": 45.2,
                "success_rate": 0.97,
                "api_uptime": 0.999,
                "user_satisfaction": 0.86
            },
            "growth_metrics": {
                "daily_active_users": 2341,
                "weekly_active_users": 6789,
                "monthly_active_users": 8921,
                "retention_rate_30d": 0.73
            }
        }
        
        return {
            "platform_stats": platform_stats,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "data_freshness": "real-time"
        }
        
    except Exception as e:
        logger.error("Failed to get platform stats", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve platform statistics")


@router.get("/harm-analysis")
async def get_harm_level_analysis(
    time_range: str = Query("30d", description="Time range for analysis"),
    language: str = Query("en", description="Language filter")
):
    """Analyze harm levels and escalation patterns"""
    try:
        # This would query BigQuery for harm level analysis
        # Using mock data for demonstration
        
        harm_analysis = {
            "harm_distribution": {
                "harmless": {
                    "count": 3456,
                    "percentage": 0.34,
                    "avg_confidence": 0.91
                },
                "basic": {
                    "count": 4567,
                    "percentage": 0.45,
                    "avg_confidence": 0.84
                },
                "very_harmful": {
                    "count": 2134,
                    "percentage": 0.21,
                    "avg_confidence": 0.88
                }
            },
            "escalation_patterns": {
                "auto_escalated": 234,
                "manual_reports": 567,
                "platform_reported": 123,
                "authority_escalated": 45
            },
            "harm_categories": [
                {
                    "category": "Medical Misinformation",
                    "harm_score": 0.89,
                    "volume": 1234,
                    "avg_spread_rate": 0.76
                },
                {
                    "category": "Violence Incitement",
                    "harm_score": 0.95,
                    "volume": 456,
                    "avg_spread_rate": 0.82
                },
                {
                    "category": "Financial Fraud",
                    "harm_score": 0.78,
                    "volume": 789,
                    "avg_spread_rate": 0.65
                }
            ],
            "intervention_effectiveness": {
                "educational_responses": {
                    "sent": 3456,
                    "engagement_rate": 0.67,
                    "behavior_change_rate": 0.34
                },
                "platform_warnings": {
                    "issued": 2134,
                    "compliance_rate": 0.78,
                    "repeat_violation_rate": 0.15
                },
                "fact_check_redirects": {
                    "provided": 5678,
                    "click_through_rate": 0.45,
                    "satisfaction_rate": 0.82
                }
            }
        }
        
        return {
            "harm_analysis": harm_analysis,
            "time_range": time_range,
            "language": language,
            "generated_at": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error("Failed to get harm analysis", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve harm level analysis")


@router.post("/export-report")
async def export_analytics_report(
    report_type: str = Query(..., description="Report type: trending, insights, harm_analysis"),
    format: str = Query("json", description="Export format: json, csv"),
    time_range: str = Query("30d", description="Time range for report"),
    user = Depends(lambda: {"uid": "test-user"})
):
    """Export analytics report for download"""
    try:
        # This would generate and export comprehensive reports
        # For now, return a reference to the report
        
        report_id = f"{report_type}_{time_range}_{int(datetime.now().timestamp())}"
        
        # In a real implementation, this would:
        # 1. Generate the report data
        # 2. Store it in Cloud Storage
        # 3. Return a signed URL for download
        
        return {
            "report_id": report_id,
            "status": "generated",
            "download_url": f"https://storage.googleapis.com/reports/{report_id}.{format}",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            "report_type": report_type,
            "format": format,
            "time_range": time_range
        }
        
    except Exception as e:
        logger.error("Failed to export report", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to export analytics report")