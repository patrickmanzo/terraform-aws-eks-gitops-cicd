import logging
import time

logger = logging.getLogger(__name__)


class RequestLoggingMiddleware:
    """
    Middleware to log all incoming requests with details
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Record start time
        start_time = time.time()

        # Get client IP
        client_ip = request.META.get('HTTP_X_FORWARDED_FOR',
                                    request.META.get('REMOTE_ADDR', 'unknown'))

        # Get request details
        method = request.method
        path = request.path
        user_agent = request.META.get('HTTP_USER_AGENT', 'unknown')

        # Process request
        response = self.get_response(request)

        # Calculate response time
        response_time = (time.time() - start_time) * 1000

        # Log the request
        log_message = (
            f"[REQUEST] {method} {path} | "
            f"Status: {response.status_code} | "
            f"IP: {client_ip} | "
            f"Response time: {response_time:.2f}ms | "
            f"User-Agent: {user_agent[:50]}"
        )

        # Use appropriate log level based on status code
        if response.status_code >= 500:
            logger.error(log_message)
        elif response.status_code >= 400:
            logger.warning(log_message)
        else:
            logger.info(log_message)

        return response
