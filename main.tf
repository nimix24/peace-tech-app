provider "aws" {
}
resource "aws_instance" "genai_service" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  key_name = "vockey"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install flask requests google-generativeai

              # Set environment variable in ~/.bashrc
              echo "export GENAI_SERVICE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /home/ec2-user/.bashrc

              git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
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
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  key_name = "vockey"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install flask

              # Set SENTIMENT_SERVICE_IP in ~/.bashrc
              echo "export SENTIMENT_SERVICE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /home/ec2-user/.bashrc

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
  vpc_security_group_ids = [aws_security_group.db_instance_sg.id]
  iam_instance_profile = "db-instance-dynamo-role"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              python3 -m ensurepip --upgrade
              python3 -m pip install --upgrade pip
              python3 -m pip install boto3

              # Set DYNAMODB_SERVICE_IP in ~/.bashrc
              echo "export DYNAMODB_SERVICE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /home/ec2-user/.bashrc

              git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
              #sudo chmod 666 /home/ec2-user/app.log
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
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
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

# Security group to allow inbound traffic to Flask
resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow SSH, Flask, and DynamoDB Local"

  # Allow HTTP traffic to Flask on port 5000
  ingress {
    from_port   = 5000
    to_port     = 5000
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

# Security group for DB Instance
resource "aws_security_group" "db_instance_sg" {
  name        = "db_instance_sg"
  description = "Allow access from data-logic-instance only"

  # Allow traffic from the data-logic-instance security group
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.flask_sg.id]
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

# Create a DynamoDB Table
resource "aws_dynamodb_table" "greetings" {
  name           = "greetings_table"
  billing_mode   = "PAY_PER_REQUEST" # Automatically scales based on usage
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S" # String type for the primary key
  }

  tags = {
    Environment = "Test"
  }
}

# ------------------------------------------------------- OUTPUTS ---------------------------------------------------

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
    dynamodb_table_name = aws_dynamodb_table.greetings.tags["Name"]
  }
}