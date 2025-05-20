# Use official Python runtime base image
FROM python:3.11-slim

# Set working directory inside container
WORKDIR /app

# Copy requirements if any (boto3 is preinstalled, but let's be explicit)
RUN pip install --no-cache-dir boto3

# Copy the microservice code
COPY main.py .

# Default environment variables (can be overridden by docker run or cloud env)
ENV POLL_INTERVAL_SECONDS=10

# Run the microservice
CMD ["python", "main.py"]

