provider "aws" {
  region = "us-west-2"
  shared_credentials_files = ["G:\\Nimrod\\Appleseeds\\Projects\\Pokemon API\\AWS details\\credentials"]
}

# Create an SQS queue
resource "aws_sqs_queue" "regular_terraform_queue" {
  name = "regular_terraform_queue"
}

# EC2 instance to run Flask
resource "aws_instance" "flask_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"

  # Security Group to allow HTTP traffic
  vpc_security_group_ids = [aws_security_group.flask_sg.id]

  # Pass environment variables for Flask to access the SQS queue
  user_data = <<-EOF
              #!/bin/bash
              # Install dependencies
              yum update -y
              yum install -y python3-pip
              pip3 install flask boto3 git

              # Set environment variable for SQS queue URL
              echo "export QUEUE_URL=${aws_sqs_queue.regular_terraform_queue.id}" >> /home/ec2-user/.bashrc

              # Download the Flask app from S3 or GitHub
              cat << 'EOF_APP' > /home/ec2-user/app.py
              ${file("path/to/your/flask_code.py")}
              EOF_APP

              # Run Flask app
              nohup python3 /home/ec2-user/app.py &
              EOF
}

# Security group to allow inbound traffic to Flask
resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow inbound traffic for Flask"

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output queue URL and EC2 public IP
output "queue_url" {
  value = aws_sqs_queue.regular_terraform_queue.id
}

output "flask_ec2_public_ip" {
  value = aws_instance.flask_ec2.public_ip
}