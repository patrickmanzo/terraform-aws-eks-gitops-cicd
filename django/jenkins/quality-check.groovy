def call(body) {
    def settings = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = settings
    body()

    container('python') {
        sh '''
            echo "🔧 Installing dependencies..."
            pip install -r requirements.txt

            echo "🎨 Checking code formatting..."
            black --check . || (echo "❌ Code formatting issues found. Run 'black .' to fix." && exit 1)

            echo "🔍 Running linting..."
            flake8 . --exclude=.venv,migrations --max-line-length=88 --extend-ignore=E203,W503

            echo "🔒 Running security checks..."
            bandit -r . -x '/tests/,/.venv/' -f json -o bandit-report.json || true
            safety check --json || true

            echo "🧪 Running unit tests..."
            pytest -v -m "unit or not (integration or smoke)" --cov=myproject --cov-report=term-missing --cov-report=xml

            echo "✅ Quality checks completed!"
        '''

        // Archive test results
        publishTestResults testResultsPattern: 'test-results.xml'
        publishCoverage adapters: [coberturaAdapter('coverage.xml')], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')

        // Archive security reports
        archiveArtifacts artifacts: 'bandit-report.json', allowEmptyArchive: true
    }
}
