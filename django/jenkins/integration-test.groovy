def call(body) {
    def settings = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = settings
    body()

    container('python') {
        sh '''
            echo "🔧 Setting up test environment..."
            pip install -r requirements.txt

            # Set test database environment
            export POSTGRES_HOST=${POSTGRES_HOST:-localhost}
            export POSTGRES_PORT=${POSTGRES_PORT:-5432}
            export POSTGRES_DB=${POSTGRES_DB:-django_test}
            export POSTGRES_USER=${POSTGRES_USER:-django_user}
            export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-pass12345}
            export DJANGO_SETTINGS_MODULE=myproject.settings_production

            echo "🗄️ Setting up test database..."
            # Wait for database to be ready
            until pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER; do
                echo "Waiting for database..."
                sleep 2
            done

            echo "📊 Running database migrations..."
            python manage.py migrate --noinput

            echo "🧪 Running integration tests..."
            pytest -v -m "integration" --tb=short

            echo "🔥 Running smoke tests..."
            pytest -v -m "smoke" --tb=short

            echo "📈 Running load tests..."
            pytest -v tests/test_integration.py::LoadTestCase --tb=short

            echo "🎯 Running full test suite with coverage..."
            pytest -v --cov=myproject --cov-report=term-missing --cov-report=xml --cov-fail-under=70

            echo "✅ Integration tests completed!"
        '''

        // Publish test results
        publishTestResults testResultsPattern: 'test-results.xml'
        publishCoverage adapters: [coberturaAdapter('coverage.xml')], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
    }
}
