# AWS Infrastructure with Terraform and Flask Application

This repository contains a Terraform configuration for setting up a basic AWS infrastructure and a Python Flask application. It deploys two EC2 instances and a DynamoDB table. One EC2 instance hosts a Flask app, while the other is configured for database-related operations.

## Features

- **Infrastructure Automation:** Provisioned using Terraform.
- **Flask Application:** A Python Flask app for sending and retrieving messages.
- **DynamoDB Table:** A serverless NoSQL database.
- **Secure Configuration:** EC2 instances secured with tailored security groups.

## Architecture

1. **Terraform Configuration:**
   - **Two EC2 instances:**
     - **Flask Instance:** Hosts the Flask application.
     - **DB Instance:** Prepares for database-related operations.
   - **DynamoDB Table:** Serverless data persistence.
   - **Security Groups:** Configured to allow only necessary traffic.

2. **Flask Application:**
   - Provides RESTful APIs to send and retrieve messages.
   - Simulates message handling using in-memory storage.

## Prerequisites

Before deploying this infrastructure, ensure you have the following:

- [Terraform](https://www.terraform.io/downloads) installed.
- AWS credentials configured locally.
- A key pair (e.g., `vockey`) exists in your AWS account for EC2 access.
- Python 3.6+ installed for running the Flask app.

## Deployment

### Step 1: Clone the Repository
```bash
git clone <repository_url>
cd <repository_folder>
