# Makefile for Django Development

.PHONY: help dev down build logs logs-web logs-db logs-all logs-tail logs-errors shell bash migrate makemigrations collectstatic test test-all test-unit test-integration test-smoke test-coverage lint security format clean health reset

# Default target
help:
	@echo "Available commands:"
	@echo "  dev          - Start development environment"
	@echo "  down         - Stop and remove containers"
	@echo "  build        - Build containers without cache"
	@echo "  logs         - Show logs (both web and db services)"
	@echo "  logs-web     - Show web service logs only"
	@echo "  logs-db      - Show database logs only"
	@echo "  logs-all     - Show all services logs with timestamps"
	@echo "  logs-tail    - Show last 50 lines of logs"
	@echo "  logs-errors  - Show only error logs (grep for ERROR/WARN)"
	@echo "  shell        - Access Django shell in container"
	@echo "  bash         - Access bash shell in web container"
	@echo "  migrate      - Run Django migrations"
	@echo "  makemigrations - Create new migrations"
	@echo "  collectstatic - Collect static files"
	@echo "  test         - Run all tests with coverage"
	@echo "  test-all     - Run tests + linting + security checks"
	@echo "  test-unit    - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  test-smoke   - Run smoke tests only"
	@echo "  test-coverage - Generate coverage report"
	@echo "  lint         - Run code linting (black, flake8)"
	@echo "  security     - Run security checks (bandit, safety)"
	@echo "  format       - Format code with black"
	@echo "  clean        - Clean up volumes and containers"
	@echo "  health       - Check application health"
	@echo "  reset        - Complete reset (clean + build + dev)"

# Start development environment
dev:
	@echo "🚀 Starting Django development environment..."
	docker-compose up -d
	@echo "✅ Environment started!"
	@echo "📱 App: http://localhost:8000"
	@echo "🩺 Health: http://localhost:8000/health"
	@echo "⚙️  Admin: http://localhost:8000/admin"

# Stop and remove containers
down:
	@echo "🛑 Stopping development environment..."
	docker-compose down
	@echo "✅ Environment stopped!"

# Build containers without cache
build:
	@echo "🔨 Building containers..."
	docker-compose build --no-cache
	@echo "✅ Build complete!"

# Show combined logs (web and database)
logs:
	@echo "📋 Showing logs for web and database services..."
	docker-compose logs -f web db

# Show web service logs only
logs-web:
	@echo "📋 Showing web service logs..."
	docker-compose logs -f web

# Show database logs only
logs-db:
	@echo "📋 Showing database logs..."
	docker-compose logs -f db

# Show all services logs with timestamps
logs-all:
	@echo "📋 Showing all services logs with timestamps..."
	docker-compose logs -f -t

# Show last 50 lines of logs
logs-tail:
	@echo "📋 Showing last 50 lines of logs..."
	docker-compose logs --tail=50 web db

# Show only error logs
logs-errors:
	@echo "🚨 Showing error logs..."
	docker-compose logs --no-color web db | grep -i -E "(error|warn|exception|traceback|fail)" || echo "No errors found in recent logs"

# Access Django shell
shell:
	docker-compose exec web python manage.py shell

# Access bash shell in web container
bash:
	docker-compose exec web bash

# Run migrations
migrate:
	@echo "🔄 Running migrations..."
	docker-compose exec web python manage.py migrate
	@echo "✅ Migrations complete!"

# Create new migrations
makemigrations:
	@echo "📝 Creating migrations..."
	docker-compose exec web python manage.py makemigrations
	@echo "✅ Migrations created!"

# Collect static files
collectstatic:
	@echo "📁 Collecting static files..."
	docker-compose exec web python manage.py collectstatic --noinput
	@echo "✅ Static files collected!"

# Run all tests with coverage
test:
	@echo "🧪 Running all tests with coverage..."
	docker-compose exec web pytest -v --cov=myproject --cov-report=term-missing
	@echo "✅ Tests complete!"

# Run comprehensive test suite (tests + linting + security)
test-all:
	@echo "🚀 Running comprehensive test suite..."
	@echo "🎨 Step 1/4: Code formatting check..."
	docker-compose exec web black --check . || (echo "❌ Code formatting issues. Run 'make format' to fix." && exit 1)
	@echo "🔍 Step 2/4: Code linting..."
	docker-compose exec web flake8 . --exclude=.venv,migrations
	@echo "🔒 Step 3/4: Security checks..."
	docker-compose exec web bandit -r . -x '/tests/,/.venv/' || true
	docker-compose exec web safety check || true
	@echo "🧪 Step 4/4: Running tests with coverage..."
	docker-compose exec web pytest -v --cov=myproject --cov-report=term-missing --cov-fail-under=80
	@echo "🎉 All checks completed successfully!"

# Run unit tests only
test-unit:
	@echo "🧪 Running unit tests..."
	docker-compose exec web pytest -v -m "unit or not (integration or smoke)"
	@echo "✅ Unit tests complete!"

# Run integration tests only
test-integration:
	@echo "🧪 Running integration tests..."
	docker-compose exec web pytest -v -m "integration"
	@echo "✅ Integration tests complete!"

# Run smoke tests only
test-smoke:
	@echo "🧪 Running smoke tests..."
	docker-compose exec web pytest -v tests/test_integration.py::SmokeTestCase
	@echo "✅ Smoke tests complete!"

# Generate coverage report
test-coverage:
	@echo "📊 Generating coverage report..."
	docker-compose exec web pytest --cov=myproject --cov-report=html --cov-report=term
	@echo "✅ Coverage report generated in htmlcov/"

# Run code linting
lint:
	@echo "🔍 Running code linting..."
	docker-compose exec web black --check .
	docker-compose exec web flake8 . --exclude=.venv,migrations
	@echo "✅ Linting complete!"

# Run security checks
security:
	@echo "🔒 Running security checks..."
	docker-compose exec web bandit -r . -x '/tests/,/.venv/' -f json -o bandit-report.json || true
	docker-compose exec web safety check --json || true
	@echo "✅ Security checks complete!"

# Format code
format:
	@echo "🎨 Formatting code..."
	docker-compose exec web black .
	@echo "✅ Code formatted!"

# Clean up everything
clean:
	@echo "🧹 Cleaning up..."
	docker-compose down --volumes --remove-orphans
	docker system prune -f
	@echo "✅ Cleanup complete!"

# Check application health
health:
	@echo "🩺 Checking application health..."
	@curl -f http://localhost:8000/health || echo "❌ Health check failed"

# Complete reset
reset: clean build dev migrate
	@echo "🔄 Complete reset finished!"
	@echo "📱 App: http://localhost:8000"
	@echo "🩺 Health: http://localhost:8000/health"
