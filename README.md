AWS Infrastructure with Terraform and Flask Application
This repository contains a Terraform configuration for setting up a basic AWS infrastructure and a Python Flask application. It deploys two EC2 instances and a DynamoDB table, with one EC2 instance hosting a Flask app and another acting as a database handler.

Features
Infrastructure Automation: Provisioned using Terraform.
Flask Application: A simple Python Flask app for sending and retrieving messages.
DynamoDB Table: Serverless database for storage.
Secure Configuration: EC2 instances with tailored security groups.
Architecture
Terraform Configuration:

Creates two EC2 instances:
Flask Instance: Hosts the Flask application.
DB Instance: Prepares for database-related operations.
Sets up a DynamoDB table for data persistence.
Defines security groups to secure the infrastructure.
Flask Application:

Provides APIs to send and receive messages.
Simulates message handling using in-memory storage.
Prerequisites
Before deploying this infrastructure, ensure the following:

Terraform is installed.
AWS credentials are configured locally.
A key pair (e.g., vockey) exists in your AWS account for EC2 access.
Python 3.6+ installed for running the Flask app.
Deployment
Step 1: Clone the Repository
bash
Copy code
git clone <repository_url>
cd <repository_folder>
Step 2: Initialize Terraform
bash
Copy code
terraform init
Step 3: Apply the Configuration
bash
Copy code
terraform apply
Note: Confirm the changes by typing yes when prompted.

Step 4: Access the Deployed Resources
After successful deployment, the public IPs of the EC2 instances and the DynamoDB table name will be displayed as outputs:

Flask EC2 Public IP: Access the Flask app at http://<public_ip>:5000.
DynamoDB Table Name: example_table.
Flask Application
Endpoints
Send Message
Endpoint: /send
Method: POST
Payload: {"message": "Your Message"}
Example:

bash
Copy code
curl -X POST -H "Content-Type: application/json" -d '{"message": "Hello AWS!"}' http://<flask_ec2_ip>:5000/send
Receive Messages
Endpoint: /receive
Method: GET
Example:

bash
Copy code
curl http://<flask_ec2_ip>:5000/receive
Clean-Up
To destroy the infrastructure and avoid unnecessary costs, run:

bash
Copy code
terraform destroy
File Structure
main.tf
Contains the Terraform configuration for provisioning AWS resources.

flask_app.py
Flask application script with APIs for sending and receiving messages.

Future Enhancements
Integrate SQS for message handling.
Add unit tests for the Flask app.
Configure CI/CD for automated deployments.