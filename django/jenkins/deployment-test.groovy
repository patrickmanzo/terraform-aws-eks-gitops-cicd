def call(body) {
    def settings = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = settings
    body()

    container('helm') {
        sh '''
            echo "🚀 Starting deployment tests..."

            # Determine environment based on branch
            if [ $(echo $GIT_BRANCH | grep ^develop$) ]; then
                ENVIRONMENT="dev"
                NAMESPACE="dev"
            elif [ $(echo $GIT_BRANCH | grep -E "^hotfix-.*") ]; then
                ENVIRONMENT="stg"
                NAMESPACE="staging"
            else
                ENVIRONMENT="test"
                NAMESPACE="citest"
            fi

            echo "📦 Deploying to environment: $ENVIRONMENT"

            # Build and deploy helm chart
            cd helm-applications/${JOB_NAME%/*}
            helm dependency build
            helm upgrade --install \\
                --values values-ci.yaml \\
                --namespace $NAMESPACE \\
                --create-namespace \\
                --set image.tag="$(cat /artifacts/${ENVIRONMENT}.artifact)" \\
                --set fullnameOverride="django-app" \\
                --wait --timeout=10m \\
                django-app-ci .

            echo "⏳ Waiting for deployment to be ready..."
            kubectl wait --for=condition=available --timeout=300s deployment/django-app-ci -n $NAMESPACE

            # Get service endpoint
            SERVICE_URL="http://django-app-ci.$NAMESPACE.svc.cluster.local:8000"
            echo "🌐 Testing service at: $SERVICE_URL"

            # Smoke tests
            echo "🔥 Running smoke tests..."

            # Test 1: Health check
            echo "Testing health endpoint..."
            health_status=$(curl --silent --output /dev/null --write-out '%{http_code}' "$SERVICE_URL/health")
            if [ "$health_status" == "200" ]; then
                echo "✅ Health check passed"
            else
                echo "❌ Health check failed with status: $health_status"
                exit 1
            fi

            # Test 2: Readiness check
            echo "Testing readiness endpoint..."
            ready_status=$(curl --silent --output /dev/null --write-out '%{http_code}' "$SERVICE_URL/ready")
            if [ "$ready_status" == "200" ]; then
                echo "✅ Readiness check passed"
            else
                echo "❌ Readiness check failed with status: $ready_status"
                exit 1
            fi

            # Test 3: Liveness check
            echo "Testing liveness endpoint..."
            alive_status=$(curl --silent --output /dev/null --write-out '%{http_code}' "$SERVICE_URL/alive")
            if [ "$alive_status" == "200" ]; then
                echo "✅ Liveness check passed"
            else
                echo "❌ Liveness check failed with status: $alive_status"
                exit 1
            fi

            # Test 4: Home page
            echo "Testing home page..."
            home_status=$(curl --silent --output /dev/null --write-out '%{http_code}' "$SERVICE_URL/")
            if [ "$home_status" == "200" ]; then
                echo "✅ Home page check passed"
            else
                echo "❌ Home page check failed with status: $home_status"
                exit 1
            fi

            # Test 5: API status
            echo "Testing API status..."
            api_response=$(curl --silent "$SERVICE_URL/api/status/")
            api_status=$(echo $api_response | grep -o '"status":"ok"' || echo "")
            if [ -n "$api_status" ]; then
                echo "✅ API status check passed"
            else
                echo "❌ API status check failed. Response: $api_response"
                exit 1
            fi

            # Performance test
            echo "🚀 Running basic performance test..."
            response_time=$(curl -o /dev/null -s -w '%{time_total}' "$SERVICE_URL/health")
            response_time_ms=$(echo "$response_time * 1000" | bc)
            echo "Response time: ${response_time_ms}ms"

            if (( $(echo "$response_time < 2.0" | bc -l) )); then
                echo "✅ Performance test passed (response time < 2s)"
            else
                echo "⚠️  Performance warning: response time > 2s"
            fi

            echo "🎉 All deployment tests passed!"
        '''
    }
}
