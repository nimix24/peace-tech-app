provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "genai_service" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  vpc_security_group_ids = (
      data.aws_security_group.existing_flask_sg.id != "" ?
      [data.aws_security_group.existing_flask_sg.id] :
      (length(aws_security_group.flask_sg) > 0 ? [aws_security_group.flask_sg[0].id] : [])
)
  iam_instance_profile = "access_secret_manager_role"
  key_name = "vockey"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install flask boto3 requests google-generativeai

              git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
              touch /home/ec2-user/app/genai_service.log
              chmod 666 /home/ec2-user/app/genai_service.log
              echo "Log file created and permissions set at $(date)" >> /home/ec2-user/app/genai_service.log
              nohup python3 /home/ec2-user/app/genai_service.py > /home/ec2-user/genai_service.log 2>&1 &
              EOF

  tags = {
    Name = "genai-service-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "sentiment_service" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  vpc_security_group_ids = (
      data.aws_security_group.existing_flask_sg.id != "" ?
      [data.aws_security_group.existing_flask_sg.id] :
      (length(aws_security_group.flask_sg) > 0 ? [aws_security_group.flask_sg[0].id] : [])
)
  key_name = "vockey"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install flask nltk
              python3 -m nltk.downloader vader_lexicon
              pip3 show nltk
              ls -l ~/.nltk_data

              git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
              nohup python3 /home/ec2-user/app/sentiment_service.py > /home/ec2-user/sentiment_service.log 2>&1 &
              EOF

  tags = {
    Name = "sentiment-service-instance"
  }
}

# EC2 instance for DB access
resource "aws_instance" "db_instance" {
  ami = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name = "vockey"

  vpc_security_group_ids = (
  data.aws_security_group.existing_db_instance_sg.id != "" ?
  [data.aws_security_group.existing_db_instance_sg.id] :
  (length(aws_security_group.db_instance_sg) > 0 ? [aws_security_group.db_instance_sg[0].id] : [])
)


  iam_instance_profile = "db-instance-dynamo-role"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install flask boto3

              git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
              touch /home/ec2-user/app/dynamo_python.log
              chmod 666 /home/ec2-user/app/dynamo_python.log
              #EOF_APP

              # Run dynamodb app
              nohup python3 /home/ec2-user/app/dynamodb_service.py > /home/ec2-user/app.log 2>&1 &
              EOF

  tags = {
    Name = "db-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 instance to run Flask
resource "aws_instance" "flask_ec2" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  vpc_security_group_ids = (
      data.aws_security_group.existing_flask_sg.id != "" ?
      [data.aws_security_group.existing_flask_sg.id] :
      (length(aws_security_group.flask_sg) > 0 ? [aws_security_group.flask_sg[0].id] : [])
)
  key_name = "vockey"

  # User data script to initialize EC2 instance and Pass environment variables for Flask to access the SQS queue
  user_data = <<-EOF
              #!/bin/bash
              # Install dependencies
              yum update -y > /var/log/user_data.log 2>&1
              yum install -y python3 git  >> /var/log/user_data.log 2>&1
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install flask boto3

              # Set environment variable for GENAI_SERVICE_IP
              echo "export GENAI_SERVICE_IP=${aws_instance.genai_service.public_ip}" >> /home/ec2-user/.bashrc

              # Set environment variable for DYNAMODB_SERVICE_IP
              echo "export DYNAMODB_SERVICE_IP=${aws_instance.db_instance.public_ip}" >> /home/ec2-user/.bashrc

              # Set environment variable for SENTIMENT_SERVICE_IP
              # Export the SENTIMENT_SERVICE_IP directly from Terraform
              echo "export SENTIMENT_SERVICE_IP=${aws_instance.sentiment_service.public_ip}" >> /home/ec2-user/.bashrc

              source /home/ec2-user/.bashrc

              # Clone the Flask app from GitHub
              git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
              #sudo chmod 666 /home/ec2-user/app.log
              #EOF_APP

              # Run Flask app
              nohup python3 /home/ec2-user/app/flask_app.py > /home/ec2-user/app.log 2>&1 &
              EOF

  tags = {
    Name = "data-logic-instance"
  }

  lifecycle {
    create_before_destroy = true
  }

}

# Data block to fetch existing security group
data "aws_security_group" "existing_flask_sg" {
  filter {
    name   = "group-name"
    values = ["flask_sg"]
  }
}

# Security group to allow inbound traffic to Flask. Use the existing security group if it exists
resource "aws_security_group" "flask_sg" {
  count = data.aws_security_group.existing_flask_sg.id != "" ? 0 : 1

  name        = "flask_sg"
  description = "Allow SSH, Flask, and DynamoDB Local"

  # Allow HTTP traffic to Flask on port 5000
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5003
    to_port     = 5003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow DynamoDB Local (port 8000)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH traffic on port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Query for the existing security group
data "aws_security_group" "existing_db_instance_sg" {
  filter {
    name   = "group-name"
    values = ["db_instance_sg"]
  }
}

# Security group for DB Instance
resource "aws_security_group" "db_instance_sg" {
  count = data.aws_security_group.existing_db_instance_sg.id != "" ? 0 : 1

  name        = "db_instance_sg"
  description = "Allow access from data-logic-instance only"

  # Allow traffic from the data-logic-instance security group
  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = (
      data.aws_security_group.existing_flask_sg.id != "" ?
      [data.aws_security_group.existing_flask_sg.id] :
      (length(aws_security_group.flask_sg) > 0 ? [aws_security_group.flask_sg[0].id] : [])
)
  }

  # Allow SSH for maintenance (optional)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_dynamodb_table" "existing_greetings_table" {
  name = "greetings_table"
}

# DynamoDB Table for storing greetings
resource "aws_dynamodb_table" "greetings" {
  count          = length(data.aws_dynamodb_table.existing_greetings_table.id) > 0 ? 0 : 1
  name           = "greetings_table"
  billing_mode   = "PAY_PER_REQUEST" # Automatically scales based on usage
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S" # String type for the primary key
  }

  tags = {
    Name = "greetings_table"
    Environment = "Test"
  }
}

data "aws_dynamodb_table" "existing_terraformlocks_table" {
  name = "terraformlocks_table"
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  count        = length(data.aws_dynamodb_table.existing_terraformlocks_table.id) > 0 ? 0 : 1
  name         = "terraformlocks_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraformlocks_table"
    Environment = "Test"
  }
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-bucket" # Replace with a unique bucket name
  force_destroy = true # Optional: Allows destroying the bucket even if it contains objects
  provider = aws

  tags = {
    Name        = "TerraformStateBucket"
    Environment = "Production"
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle Rules for Object Management
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "ExpireNonCurrentVersions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30 # Automatically delete noncurrent object versions after 30 days
    }
  }

  rule {
    id     = "AbortIncompleteMultipartUpload"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Abort incomplete uploads after 7 days
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "terraform.tfstate"        # Path to the state file in the bucket
    region         = "us-west-2"
    dynamodb_table = "terraformlocks_table"
    encrypt        = true                       # Enable server-side encryption
  }
}

# ------------------------------------------------------- OUTPUTS ---------------------------------------------------

output "greetings_table_name" {
  value = coalesce(
    try(data.aws_dynamodb_table.existing_greetings_table.name, null),
    try(aws_dynamodb_table.greetings[0].name, null)
  )
}

output "terraformlocks_table_name" {
  value = coalesce(
    try(data.aws_dynamodb_table.existing_terraformlocks_table.name, null),
    try(aws_dynamodb_table.terraform_locks[0].name, null)
  )
}

output "flask_sg_id" {
  value = coalesce(
    try(data.aws_security_group.existing_flask_sg.id, null),
    try(aws_security_group.flask_sg[0].id, null)
  )
}

output "db_instance_sg_id" {
  value = coalesce(
    try(data.aws_security_group.existing_db_instance_sg.id, null),
    try(aws_security_group.db_instance_sg[0].id, null)
  )
}

output "service_ips" {
  value = {
    flask_ec2_public_ip           = aws_instance.flask_ec2.public_ip
    genai_service_public_ip       = aws_instance.genai_service.public_ip
    sentiment_service_public_ip   = aws_instance.sentiment_service.public_ip
    dynamodb_service_public_ip    = aws_instance.db_instance.public_ip
  }
  description = "Public IPs of all microservices"
}

output "instance_names" {
  value = {
    data_logic_instance = aws_instance.flask_ec2.tags["Name"]
    db_instance = aws_instance.db_instance.tags["Name"]
  }
}