provider "aws" {
  region = "us-west-2"
}

locals {
  flask_sg_id = aws_security_group.flask_sg.id
  db_instance_sg = aws_security_group.db_instance_sg.id
}

#locals {
  #flask_sg_id = length(aws_security_group.flask_sg) > 0 ? [aws_security_group.flask_sg[0].id] : []
  #db_instance_sg = length(aws_security_group.db_instance_sg) > 0 ? [aws_security_group.db_instance_sg[0].id] : []
 # flask_sg_id = try(data.aws_security_group.existing_flask_sg.id, aws_security_group.flask_sg[0].id)
 # db_instance_sg = try(data.aws_security_group.existing_db_instance_sg.id, aws_security_group.db_instance_sg[0].id)
#}

module "dynamodb" {
  source                      = "./modules/dynamodb"
  greetings_table_name        = "greetings_table"
  terraform_locks_table_name_master  = "terraform_locks_table_master"
  terraform_locks_table_name_ec2_branch = "terraform_locks_table_ec2_branch"
  tags = {
    Environment = "Test"
  }
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-266735837076"
    key            = "ec2-branch/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform_locks_table_ec2_branch"
    #encrypt        = true
  }
}

data "aws_s3_bucket" "existing" {
  bucket = "terraform-state-bucket-266735837076"
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  count = length(data.aws_s3_bucket.existing.id) > 0 ? 0 : 1
  bucket = "terraform-state-bucket-266735837076"

  tags = {
    Environment = "Test"
    Owner       = "NimCorporation"
  }
}

resource "aws_instance" "genai_service" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  iam_instance_profile = "access_secret_manager_role"
  key_name = "vockey"
  vpc_security_group_ids = [local.flask_sg_id]

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

  depends_on = [
    module.dynamodb
  ]

}

resource "aws_instance" "sentiment_service" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name = "vockey"
  vpc_security_group_ids = [local.flask_sg_id]


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
  depends_on = [module.dynamodb]
}

# EC2 instance for DB access
resource "aws_instance" "db_instance" {
  ami = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name = "vockey"
  iam_instance_profile = "db-instance-dynamo-role"
  vpc_security_group_ids = [local.db_instance_sg]

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
  depends_on = [module.dynamodb]
}

# EC2 instance to run Flask
resource "aws_instance" "flask_ec2" {
  ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name = "vockey"
  vpc_security_group_ids = [local.flask_sg_id]

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
  depends_on = [
    module.dynamodb,
    aws_instance.genai_service,
    aws_instance.db_instance,
    aws_instance.sentiment_service
  ]

}

#Data block to fetch existing security group
# data "aws_security_group" "existing_flask_sg" {
#   filter {
#     name   = "group-name"
#     values = ["flask_sg"]
#   }
# }

# Security group to allow inbound traffic to Flask. Use the existing security group if it exists
resource "aws_security_group" "flask_sg" {
  #count = try(data.aws_security_group.existing_flask_sg.id,"") != "" ? 0 : 1
  name        = "flask_sg"
  description = "Allow SSH, Flask, and DynamoDB Local"

  # Allow HTTP traffic to Flask on port 5000
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 6000
    to_port     = 6000
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

#Query for the existing security group
# data "aws_security_group" "existing_db_instance_sg" {
#   filter {
#     name   = "group-name"
#     values = ["db_instance_sg"]
#   }
# }

# Security group for DB Instance
resource "aws_security_group" "db_instance_sg" {
  #count = try(data.aws_security_group.existing_db_instance_sg.id,"") != "" ? 0 : 1
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
    security_groups = [local.flask_sg_id]
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




# ------------------------------------------------------- OUTPUTS ---------------------------------------------------

output "dynamodb_tables" {
  value = {
    greetings_table = "greetings_table"
    terraform_locks_table = "terraform_locks_table__ec2_branch"
  }
}

output "security_group_ids" {
  value = {
    flask_sg_id      = local.flask_sg_id
    db_instance_sg_id = local.db_instance_sg
  }
  description = "Security group IDs for Flask and DB instances."
}

# output "debug_flask_sg" {
#   value = {
#     length = length(aws_security_group.flask_sg)
#     id     = length(aws_security_group.flask_sg) > 0 ? aws_security_group.flask_sg[0].id : null
#   }
# }


# output "flask_sg_id" {
#   value = coalesce(
#     try(data.aws_security_group.existing_flask_sg.id, null),
#     try(aws_security_group.flask_sg[0].id, null)
#   )
# }
#
# output "db_instance_sg_id" {
#   value = coalesce(
#     try(data.aws_security_group.existing_db_instance_sg.id, null),
#     try(aws_security_group.db_instance_sg[0].id, null)
#   )
# }

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