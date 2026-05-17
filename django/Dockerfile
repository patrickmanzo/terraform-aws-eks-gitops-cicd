FROM python:3.13-slim

WORKDIR /app

# Install system dependencies including PostgreSQL development libraries
RUN apt-get update && apt-get install -y \
    postgresql-client \
    libpq-dev \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --upgrade -r requirements.txt

#ENV POSTGRES_HOST=${POSTGRES_HOST}
#ENV POSTGRES_PORT=${POSTGRES_PORT}
#ENV POSTGRES_NAME=${POSTGRES_NAME}
#ENV POSTGRES_USER=${POSTGRES_USER}
#ENV POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

COPY . .

# Collect static files for production
RUN python manage.py collectstatic --noinput || echo "No static files to collect"

# Create a non-root user
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Use Gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "myproject.wsgi:application"]
