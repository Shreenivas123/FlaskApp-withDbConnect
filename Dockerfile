# Use official Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose Flask port
EXPOSE 5000

# Set environment variable for Flask
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0

# Database connection parameters (override at runtime)
ENV DB_HOST=""
ENV DB_USER=""
ENV DB_PASS=""
ENV DB_NAME=""

# Run the Flask app
CMD ["flask", "run"]
