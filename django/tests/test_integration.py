"""
Integration tests for Django application
"""

import json
import time
from django.test import TestCase, TransactionTestCase
from django.db import connection


class IntegrationTestCase(TransactionTestCase):
    """Integration tests that test the full application stack"""

    def test_full_health_check_workflow(self):
        """Test complete health check workflow"""
        # Test that all health endpoints work together
        endpoints = [
            ("/health/", "healthy"),
            ("/ready/", "ready"),
            ("/alive/", "alive"),
        ]

        for endpoint, expected_status in endpoints:
            with self.subTest(endpoint=endpoint):
                response = self.client.get(endpoint)
                self.assertEqual(response.status_code, 200)
                data = json.loads(response.content)
                self.assertEqual(data["status"], expected_status)

    def test_application_startup_sequence(self):
        """Test that application starts up correctly"""
        # Test startup probe sequence
        response = self.client.get("/health/")
        self.assertEqual(response.status_code, 200)

        # Test readiness after startup
        response = self.client.get("/ready/")
        self.assertEqual(response.status_code, 200)

        # Test liveness
        response = self.client.get("/alive/")
        self.assertEqual(response.status_code, 200)

    def test_database_operations(self):
        """Test basic database operations work"""
        with connection.cursor() as cursor:
            # Test basic query
            cursor.execute("SELECT version()")
            version = cursor.fetchone()
            self.assertIsNotNone(version)

            # Test that we can create and query a test table
            cursor.execute(
                """
                CREATE TEMPORARY TABLE test_table (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(100)
                )
            """
            )

            cursor.execute("INSERT INTO test_table (name) VALUES ('test')")
            cursor.execute("SELECT name FROM test_table WHERE name = 'test'")
            result = cursor.fetchone()
            self.assertEqual(result[0], "test")

    def test_performance_benchmarks(self):
        """Test basic performance benchmarks"""
        # Test health endpoint response time
        start_time = time.time()
        response = self.client.get("/health/")
        response_time = (time.time() - start_time) * 1000

        self.assertEqual(response.status_code, 200)
        self.assertLess(response_time, 1000)  # Should respond in < 1 second

        # Test that response includes timing info
        data = json.loads(response.content)
        self.assertIn("response_time_ms", data)
        self.assertIsInstance(data["response_time_ms"], (int, float))

    def test_concurrent_requests(self):
        """Test application handles concurrent requests"""
        import threading
        import queue

        results = queue.Queue()

        def make_request():
            try:
                response = self.client.get("/alive/")
                results.put(response.status_code)
            except Exception as e:
                results.put(str(e))

        # Create multiple threads
        threads = []
        for _ in range(10):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
            thread.start()

        # Wait for all threads to complete
        for thread in threads:
            thread.join()

        # Check all requests succeeded
        while not results.empty():
            result = results.get()
            self.assertEqual(result, 200)


class SmokeTestCase(TestCase):
    """Smoke tests for critical functionality"""

    def test_critical_endpoints_available(self):
        """Smoke test: Verify all critical endpoints are available"""
        critical_endpoints = [
            "/",
            "/health/",
            "/ready/",
            "/alive/",
            "/admin/",
            "/api/status/",
        ]

        for endpoint in critical_endpoints:
            with self.subTest(endpoint=endpoint):
                response = self.client.get(endpoint)
                # All endpoints should return something (not 404/500)
                self.assertNotIn(response.status_code, [404, 500])

    def test_database_smoke_test(self):
        """Smoke test: Basic database connectivity"""
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                self.assertEqual(result[0], 1)
        except Exception as e:
            self.fail(f"Database smoke test failed: {e}")

    def test_static_files_smoke_test(self):
        """Smoke test: Static files configuration is proper"""
        from django.conf import settings

        # Test that static files settings are configured
        self.assertIsNotNone(settings.STATIC_URL)
        self.assertIsNotNone(settings.STATIC_ROOT)

        # In production, static files are served by web server
        # (nginx/cloudfront) so we just test that the configuration exists
        self.assertTrue(hasattr(settings, "STATIC_URL"))
        self.assertTrue(hasattr(settings, "STATIC_ROOT"))

    def test_application_configuration(self):
        """Smoke test: Application is properly configured"""
        from django.conf import settings

        # Check critical settings
        self.assertIsNotNone(settings.DATABASES)
        self.assertIn("default", settings.DATABASES)
        self.assertIsNotNone(settings.SECRET_KEY)


class LoadTestCase(TestCase):
    """Basic load testing"""

    def test_health_endpoint_load(self):
        """Test health endpoint under load"""
        response_times = []

        for _ in range(50):
            start_time = time.time()
            response = self.client.get("/health/")
            response_time = (time.time() - start_time) * 1000

            self.assertEqual(response.status_code, 200)
            response_times.append(response_time)

        # Calculate average response time
        avg_response_time = sum(response_times) / len(response_times)
        max_response_time = max(response_times)

        # Assert performance requirements
        self.assertLess(avg_response_time, 100)  # Average < 100ms
        self.assertLess(max_response_time, 500)  # Max < 500ms
