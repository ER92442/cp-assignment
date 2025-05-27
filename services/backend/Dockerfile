# Use official Python runtime base image
FROM python:3.13-slim

# Set working directory inside container
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the microservice code
COPY main.py .

# Default environment variables (can be overridden by docker run or cloud env)
ENV POLL_INTERVAL_SECONDS=10

# Run the microservice
CMD ["python", "main.py"]

