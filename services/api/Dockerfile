# Use official Python image
FROM python:3.13-slim

# Set work directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code main.py file
COPY main.py .

# Set environment variable to prevent bytecode .pyc files
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Expose the port used by FastAPI
EXPOSE 8000

# Set default command to run the app
CMD ["python", "main.py"]
