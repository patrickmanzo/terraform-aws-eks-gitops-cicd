"""
URL configuration for myproject project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path
from django.shortcuts import render
from django.http import JsonResponse, HttpResponse
from django.conf import settings
from django.conf.urls.static import static
from myproject.health.views import (
    health_check,
    readiness_check,
    liveness_check,
)
import django
import os


def home_view(request):
    """Home page with HTML template"""
    context = {
        "django_version": django.get_version(),
        "environment": os.getenv("DJANGO_ENV", "development"),
    }
    return render(request, "home.html", context)


def api_status(request):
    """API endpoint for status check"""
    return JsonResponse(
        {
            "message": "Django app is running!",
            "status": "ok",
            "endpoints": {
                "health": "/health/",
                "ready": "/ready/",
                "alive": "/alive/",
                "admin": "/admin/",
            },
        }
    )


# ✅ Add favicon handler
def favicon_view(request):
    """Serve favicon or return 204 No Content"""
    # Return empty response to avoid 404 errors in logs
    return HttpResponse(status=204)


urlpatterns = [
    path("admin/", admin.site.urls),
    path("", home_view, name="home"),
    path("api/status/", api_status, name="api_status"),
    path("health/", health_check, name="health"),
    path("ready/", readiness_check, name="ready"),
    path("alive/", liveness_check, name="alive"),
    # ✅ Add favicon route
    path("favicon.ico", favicon_view, name="favicon"),
]

# Serve static files during development
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
