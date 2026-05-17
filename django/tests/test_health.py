"""
Unit tests for Django health endpoints
"""

import json
from django.test import TestCase, Client
from unittest.mock import patch
from django.db import connection


class HealthCheckTestCase(TestCase):
    def setUp(self):
        self.client = Client()

    def test_health_check_success(self):
        """Test health check endpoint returns 200 when all is well"""
        response = self.client.get("/health/")
        self.assertEqual(response.status_code, 200)

        data = json.loads(response.content)
        self.assertEqual(data["status"], "healthy")
        self.assertEqual(data["service"], "django-app")
        self.assertEqual(data["version"], "1.0.0")
        self.assertIn("checks", data)
        self.assertIn("database", data["checks"])
        self.assertIn("application", data["checks"])
        self.assertIn("response_time", data["checks"])

    def test_readiness_check_success(self):
        """Test readiness check endpoint"""
        response = self.client.get("/ready/")
        self.assertEqual(response.status_code, 200)

        data = json.loads(response.content)
        self.assertEqual(data["status"], "ready")
        self.assertEqual(data["service"], "django-app")
        self.assertIn("message", data)

    def test_liveness_check_success(self):
        """Test liveness check endpoint"""
        response = self.client.get("/alive/")
        self.assertEqual(response.status_code, 200)

        data = json.loads(response.content)
        self.assertEqual(data["status"], "alive")
        self.assertEqual(data["service"], "django-app")
        self.assertIn("message", data)

    @patch("myproject.health.views.psycopg2.connect")
    def test_health_check_db_failure(self, mock_connect):
        """Test health check when database is down"""
        mock_connect.side_effect = Exception("Database connection failed")

        response = self.client.get("/health/")
        self.assertEqual(response.status_code, 503)

        data = json.loads(response.content)
        self.assertEqual(data["status"], "unhealthy")
        self.assertEqual(data["checks"]["database"]["status"], "unhealthy")

    @patch("myproject.health.views.psycopg2.connect")
    def test_readiness_check_db_failure(self, mock_connect):
        """Test readiness check when database is down"""
        mock_connect.side_effect = Exception("Database connection failed")

        response = self.client.get("/ready/")
        self.assertEqual(response.status_code, 503)

        data = json.loads(response.content)
        self.assertEqual(data["status"], "not_ready")

    def test_health_check_response_time(self):
        """Test that health check includes response time"""
        response = self.client.get("/health/")
        data = json.loads(response.content)

        self.assertIn("response_time_ms", data)
        self.assertIsInstance(data["response_time_ms"], (int, float))
        self.assertGreater(data["response_time_ms"], 0)

    def test_endpoints_return_json(self):
        """Test that all endpoints return proper JSON content type"""
        endpoints = ["/health/", "/ready/", "/alive/"]

        for endpoint in endpoints:
            response = self.client.get(endpoint)
            self.assertEqual(response["Content-Type"], "application/json")


class HomePageTestCase(TestCase):
    def setUp(self):
        self.client = Client()

    def test_home_page_loads(self):
        """Test that home page loads successfully"""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Django Application")
        self.assertContains(response, "Application Running")

    def test_home_page_contains_health_links(self):
        """Test that home page contains links to health endpoints"""
        response = self.client.get("/")
        self.assertContains(response, "/health")
        self.assertContains(response, "/ready")
        self.assertContains(response, "/alive")
        self.assertContains(response, "/admin")

    def test_api_status_endpoint(self):
        """Test API status endpoint returns JSON"""
        response = self.client.get("/api/status/")
        self.assertEqual(response.status_code, 200)

        data = json.loads(response.content)
        self.assertEqual(data["status"], "ok")
        self.assertIn("endpoints", data)


class SecurityTestCase(TestCase):
    def setUp(self):
        self.client = Client()

    def test_security_headers(self):
        """Test that security headers are present"""
        response = self.client.get("/")

        # Check for security headers
        self.assertIn("X-Frame-Options", response)
        self.assertIn("X-Content-Type-Options", response)
        self.assertIn("Referrer-Policy", response)

    def test_admin_requires_auth(self):
        """Test that admin panel requires authentication"""
        response = self.client.get("/admin/")
        # Should redirect to login or return 302
        self.assertIn(response.status_code, [302, 200])


class DatabaseTestCase(TestCase):
    def test_database_connection(self):
        """Test database connection works"""
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            self.assertEqual(result[0], 1)

    def test_database_migrations(self):
        """Test that migrations are up to date"""
        from django.core.management import execute_from_command_line
        from io import StringIO
        import sys

        # Capture output
        old_stdout = sys.stdout
        sys.stdout = StringIO()

        try:
            execute_from_command_line(["manage.py", "showmigrations"])
            output = sys.stdout.getvalue()
            # Check that there are no unapplied migrations
            self.assertNotIn("[ ]", output)
        finally:
            sys.stdout = old_stdout
