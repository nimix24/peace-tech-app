# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy application code to the container
COPY . /app

# Install dependencies
RUN pip install --no-cache-dir flask requests boto3

# Expose the application port
EXPOSE 5000

# Run the application
CMD ["python", "flask_app.py"]
