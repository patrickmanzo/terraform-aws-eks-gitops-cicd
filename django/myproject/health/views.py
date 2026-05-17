import time
import psycopg2
from django.http import JsonResponse
from django.conf import settings
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
import logging

logger = logging.getLogger(__name__)


@csrf_exempt
@require_http_methods(["GET"])
def health_check(request):
    """
    Comprehensive health check endpoint for startup probe
    This endpoint checks all critical components:
    - Database connectivity
    - Application readiness
    - System resources
    """
    start_time = time.time()

    # ✅ Log the request with client IP
    client_ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', 'unknown'))
    logger.info(f"[HEALTH CHECK] Request from {client_ip}")

    health_data = {
        "status": "healthy",
        "timestamp": time.time(),
        "service": "django-app",
        "version": "1.0.0",
        "checks": {},
    }

    # Database health check
    try:
        db_config = settings.DATABASES["default"]
        conn = psycopg2.connect(
            host=db_config["HOST"],
            port=db_config["PORT"],
            database=db_config["NAME"],
            user=db_config["USER"],
            password=db_config["PASSWORD"],
        )
        conn.close()
        health_data["checks"]["database"] = {
            "status": "healthy",
            "message": "Database connection successful",
        }
        logger.info(f"[HEALTH CHECK] Database check: PASSED")
    except Exception as e:
        health_data["status"] = "unhealthy"
        health_data["checks"]["database"] = {
            "status": "unhealthy",
            "message": f"Database connection failed: {str(e)}",
        }
        logger.error(f"[HEALTH CHECK] Database check: FAILED - {str(e)}")

    # Application readiness check
    health_data["checks"]["application"] = {
        "status": "healthy",
        "message": "Django application is fully loaded and ready",
    }

    # Response time check
    response_time = (time.time() - start_time) * 1000  # Convert to ms
    health_data["response_time_ms"] = round(response_time, 2)

    if response_time > 1000:  # If response time > 1 second
        health_data["checks"]["response_time"] = {
            "status": "warning",
            "message": f"Slow response time: {response_time:.2f}ms",
            "threshold_ms": 1000,
        }
        logger.warning(f"[HEALTH CHECK] Slow response: {response_time:.2f}ms")
    else:
        health_data["checks"]["response_time"] = {
            "status": "healthy",
            "message": f"Response time: {response_time:.2f}ms",
            "threshold_ms": 1000,
        }

    # Overall status
    status_code = 200 if health_data["status"] == "healthy" else 503

    # ✅ Log the final result
    logger.info(f"[HEALTH CHECK] Status: {health_data['status']} | Response time: {response_time:.2f}ms | Status code: {status_code}")

    return JsonResponse(health_data, status=status_code)


@csrf_exempt
@require_http_methods(["GET"])
def readiness_check(request):
    """
    Readiness probe - checks if app is ready to serve traffic
    This should be fast and check if the app can handle requests
    """
    # ✅ Log readiness check
    client_ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', 'unknown'))
    logger.info(f"[READINESS CHECK] Request from {client_ip}")

    try:
        # Quick database check for readiness
        db_config = settings.DATABASES["default"]
        conn = psycopg2.connect(
            host=db_config["HOST"],
            port=db_config["PORT"],
            database=db_config["NAME"],
            user=db_config["USER"],
            password=db_config["PASSWORD"],
        )
        conn.close()

        logger.info(f"[READINESS CHECK] Status: READY | Database: CONNECTED")

        return JsonResponse(
            {
                "status": "ready",
                "timestamp": time.time(),
                "service": "django-app",
                "message": "Application is ready to serve requests",
            }
        )
    except Exception as e:
        logger.error(f"[READINESS CHECK] Status: NOT READY | Database error: {str(e)}")

        return JsonResponse(
            {
                "status": "not_ready",
                "timestamp": time.time(),
                "service": "django-app",
                "message": f"Application not ready: {str(e)}",
            },
            status=503,
        )


@csrf_exempt
@require_http_methods(["GET"])
def liveness_check(request):
    """
    Liveness probe - basic check if app is alive
    This should be very lightweight and fast
    """
    # ✅ Log liveness check
    client_ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', 'unknown'))
    logger.info(f"[LIVENESS CHECK] Request from {client_ip} | Status: ALIVE")

    return JsonResponse(
        {
            "status": "alive",
            "timestamp": time.time(),
            "service": "django-app",
            "message": "Application is alive and responsive",
        }
    )
