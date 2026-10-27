# Dockerfile for a Django project.
# Replace <PROJECT_PACKAGE> with the Python package that contains wsgi.py/asgi.py.

# Pin a specific minor version of a slim Python image.
FROM python:3.13-slim

# Stop Python from writing .pyc files and buffer output line-by-line.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies first so this layer is cached until requirements.txt changes.
# requirements.txt should include gunicorn and psycopg[binary] (or psycopg2-binary).
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the application source.
COPY . .

# Create a non-root user and give it ownership of the writable directories.
RUN addgroup --system app \
    && adduser --system --ingroup app app \
    && mkdir -p /app/staticfiles /app/media \
    && chown -R app:app /app

# Run as the non-root user.
USER app

# Document the port Gunicorn listens on inside the container.
EXPOSE 8000

# Default command. Override it with docker run or Compose when needed.
CMD ["gunicorn", "<PROJECT_PACKAGE>.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
