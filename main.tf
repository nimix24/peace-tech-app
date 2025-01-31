provider "aws" {
  region = "us-west-2"
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

# ------------------------------------------------ ECR REPOSITORY AND ECS CLUSTER ---------------------------------------------------

# resource "aws_ecr_repository" "flask_repo" {
#   name = "flask-app"
# }

# --------------------------------------------------- ALB ---------------------------------------------------

# Create the Load Balancer
resource "aws_lb" "flask_lb" {
  name               = "flask-lb"
  internal           = false  # Set to false to make it publicly accessible
  load_balancer_type = "application"
  security_groups    = [aws_security_group.flask_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "flask-lb"
  }
}

# Create Target Group for ECS Service
resource "aws_lb_target_group" "flask_target_group" {
  name        = "flask-target-group"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.my_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "flask-target-group"
  }
}

# Create Listener for the ALB
resource "aws_lb_listener" "flask_listener" {
  load_balancer_arn = aws_lb.flask_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_target_group.arn
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}



# --------------------------------------------------- ECR OF ALB ---------------------------------------------------

data "aws_ecr_repository" "flask_repo" {
  name = "flask-app"
}

data "aws_ecr_repository" "genai_repo" {
  name = "genai-service"
}

data "aws_ecr_repository" "sentiment_repo" {
  name = "sentiment-service"
}

data "aws_ecr_repository" "dynamodb_repo" {
  name = "dynamodb-service"
}

resource "aws_ecs_cluster" "flask_cluster" {
  name = "flask-cluster"
}

resource "aws_iam_service_linked_role" "ecs_service_role" {
  aws_service_name = "ecs.amazonaws.com"
}



# ------------------------------------------------------- VPC AND SUBNETS ---------------------------------------------------

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2b"
  tags = {
    Name = "public-subnet-2"
  }
}


# ------------------------------------------------------- SECURITY GROUPS ---------------------------------------------------

# Security group to allow inbound traffic to Flask. Use the existing security group if it exists
resource "aws_security_group" "flask_sg" {
  #count = try(data.aws_security_group.existing_flask_sg.id,"") != "" ? 0 : 1
  name        = "flask_sg"
  description = "Allow SSH, Flask, and DynamoDB Local"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

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


# ---------------------------------------------------- END SECURITY GROUPS ---------------------------------------------------


# ------------------------------------------------- START ECS TASK DEFINITIONS ---------------------------------------------------


resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "flask-app",
      image     = "${data.aws_ecr_repository.flask_repo.repository_url}:latest",
      essential = true,
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "GENAI_SERVICE_URL"
          value = "http://genai-service.local:5001"
        },
        {
          name  = "DYNAMODB_SERVICE_URL"
          value = "http://dynamodb-service.local:5002"
        },
        {
          name  = "SENTIMENT_SERVICE_URL"
          value = "http://sentiment-service.local:5003"
        }
      ]
   }
 ])
}

resource "aws_ecs_task_definition" "genai_task" {
  family                   = "genai-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "genai-service",
      image     = "${data.aws_ecr_repository.genai_repo.repository_url}:latest", # Replace with your ECR repo
      essential = true,
      portMappings = [
        {
          containerPort = 5001
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "sentiment_task" {
  family                   = "sentiment-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "sentiment-service",
      image     = "${data.aws_ecr_repository.sentiment_repo.repository_url}:latest", # Replace with your ECR repo
      essential = true,
      portMappings = [
        {
          containerPort = 5003
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "dynamodb_task" {
  family                   = "dynamodb-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "dynamodb-service",
      image     = "${data.aws_ecr_repository.dynamodb_repo.repository_url}:latest", # Replace with your ECR repo
      essential = true,
      portMappings = [
        {
          containerPort = 5002
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "dynamodb_service" {
  name            = "dynamodb-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.dynamodb_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups = [aws_security_group.flask_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.dynamodb_service.arn
  }

  depends_on = [aws_lb_listener.flask_listener]
}

resource "aws_service_discovery_service" "dynamodb_service" {
  name        = "dynamodb-service"
  namespace_id = aws_service_discovery_private_dns_namespace.my_namespace.id
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.my_namespace.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}


resource "aws_ecs_service" "sentiment_service" {
  name            = "sentiment-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.sentiment_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups = [aws_security_group.flask_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sentiment_service.arn
  }

  depends_on = [aws_lb_listener.flask_listener]
}

resource "aws_service_discovery_service" "sentiment_service" {
  name        = "sentiment-service"
  namespace_id = aws_service_discovery_private_dns_namespace.my_namespace.id
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.my_namespace.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}


resource "aws_ecs_service" "genai_service" {
  name            = "genai-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.genai_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups = [aws_security_group.flask_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.genai_service.arn
  }

  depends_on = [aws_lb_listener.flask_listener]
}

resource "aws_service_discovery_private_dns_namespace" "my_namespace" {
  name        = "local"
  vpc         = aws_vpc.my_vpc.id
  description = "Private namespace for ECS services"
}

resource "aws_service_discovery_service" "genai_service" {
  name        = "genai-service"
  namespace_id = aws_service_discovery_private_dns_namespace.my_namespace.id
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.my_namespace.id
    dns_records {
      type = "A"
      ttl  = 60
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}


resource "aws_ecs_service" "flask_service" {
  depends_on = [
    aws_ecs_task_definition.flask_task,
    aws_iam_service_linked_role.ecs_service_role,
    aws_lb_listener.flask_listener
  ]
  name            = "flask-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  #task_definition = "${aws_ecs_task_definition.flask_task.family}:${aws_ecs_task_definition.flask_task.revision}"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]  # Replace with your subnets
    security_groups = [aws_security_group.flask_sg.id]
    #assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_target_group.arn
    container_name   = "flask-app"
    container_port   = 5000
  }
}



# ------------------------------------------------------- OUTPUTS ---------------------------------------------------

output "flask_alb_dns" {
  value = aws_lb.flask_lb.dns_name
  description = "DNS name of the Load Balancer"
}


# output "flask_service_task_public_ips" {
#   value = aws_ecs_service.flask_service.network_configuration[0].assign_public_ip
#   description = "Public IPs of the Flask service tasks"
# }








# ------------------------------------------------------- END OUTPUTS ---------------------------------------------------




# ------------------------------------------------------- END OF ECS RESOURCES ---------------------------------------------------

# resource "aws_instance" "genai_service" {
#   ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
#   instance_type = "t2.micro"
#   iam_instance_profile = "access_secret_manager_role"
#   key_name = "vockey"
#   vpc_security_group_ids = [local.flask_sg_id]
#
#   user_data = <<-EOF
#               #!/bin/bash
#               yum update -y
#               yum install -y python3 git
#               python3 -m ensurepip --upgrade
#               python3 -m pip install --upgrade pip
#               python3 -m pip install flask boto3 requests google-generativeai
#
#               git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
#               touch /home/ec2-user/app/genai_service.log
#               chmod 666 /home/ec2-user/app/genai_service.log
#               echo "Log file created and permissions set at $(date)" >> /home/ec2-user/app/genai_service.log
#               nohup python3 /home/ec2-user/app/genai_service.py > /home/ec2-user/genai_service.log 2>&1 &
#               EOF
#
#   tags = {
#     Name = "genai-service-instance"
#   }
#
#   lifecycle {
#     create_before_destroy = true
#   }
#
#   depends_on = [
#     module.dynamodb
#   ]
#
# }
#
# resource "aws_instance" "sentiment_service" {
#   ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
#   instance_type = "t2.micro"
#   key_name = "vockey"
#   vpc_security_group_ids = [local.flask_sg_id]
#
#
#   user_data = <<-EOF
#               #!/bin/bash
#               yum update -y
#               yum install -y python3 git
#               python3 -m ensurepip --upgrade
#               python3 -m pip install --upgrade pip
#               python3 -m pip install flask nltk
#               python3 -m nltk.downloader vader_lexicon
#               pip3 show nltk
#               ls -l ~/.nltk_data
#
#               git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
#               nohup python3 /home/ec2-user/app/sentiment_service.py > /home/ec2-user/sentiment_service.log 2>&1 &
#               EOF
#
#   tags = {
#     Name = "sentiment-service-instance"
#   }
#   depends_on = [module.dynamodb]
# }
#
# # EC2 instance for DB access
# resource "aws_instance" "db_instance" {
#   ami = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
#   instance_type = "t2.micro"
#   key_name = "vockey"
#   iam_instance_profile = "db-instance-dynamo-role"
#   vpc_security_group_ids = [local.db_instance_sg]
#
#   user_data = <<-EOF
#               #!/bin/bash
#               yum update -y
#               yum install -y python3 git
#               python3 -m ensurepip --upgrade
#               python3 -m pip install --upgrade pip
#               python3 -m pip install flask boto3
#
#               git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
#               touch /home/ec2-user/app/dynamo_python.log
#               chmod 666 /home/ec2-user/app/dynamo_python.log
#               #EOF_APP
#
#               # Run dynamodb app
#               nohup python3 /home/ec2-user/app/dynamodb_service.py > /home/ec2-user/app.log 2>&1 &
#               EOF
#
#   tags = {
#     Name = "db-instance"
#   }
#
#   lifecycle {
#     create_before_destroy = true
#   }
#   depends_on = [module.dynamodb]
# }
#
# # EC2 instance to run Flask
# resource "aws_instance" "flask_ec2" {
#   ami           = "ami-066a7fbea5161f451"  # Amazon Linux 2 AMI
#   instance_type = "t2.micro"
#   key_name = "vockey"
#   vpc_security_group_ids = [local.flask_sg_id]
#
#   # User data script to initialize EC2 instance and Pass environment variables for Flask to access the SQS queue
#   user_data = <<-EOF
#               #!/bin/bash
#               # Install dependencies
#               yum update -y > /var/log/user_data.log 2>&1
#               yum install -y python3 git  >> /var/log/user_data.log 2>&1
#               python3 -m ensurepip --upgrade
#               python3 -m pip install --upgrade pip
#               python3 -m pip install flask boto3
#
#               # Set environment variable for GENAI_SERVICE_IP
#               echo "export GENAI_SERVICE_IP=${aws_instance.genai_service.public_ip}" >> /home/ec2-user/.bashrc
#
#               # Set environment variable for DYNAMODB_SERVICE_IP
#               echo "export DYNAMODB_SERVICE_IP=${aws_instance.db_instance.public_ip}" >> /home/ec2-user/.bashrc
#
#               # Set environment variable for SENTIMENT_SERVICE_IP
#               # Export the SENTIMENT_SERVICE_IP directly from Terraform
#               echo "export SENTIMENT_SERVICE_IP=${aws_instance.sentiment_service.public_ip}" >> /home/ec2-user/.bashrc
#
#               source /home/ec2-user/.bashrc
#
#               # Clone the Flask app from GitHub
#               git clone https://github.com/nimix24/peace-tech-app.git /home/ec2-user/app
#               #sudo chmod 666 /home/ec2-user/app.log
#               #EOF_APP
#
#               # Run Flask app
#               nohup python3 /home/ec2-user/app/flask_app.py > /home/ec2-user/app.log 2>&1 &
#               EOF
#
#   tags = {
#     Name = "data-logic-instance"
#   }
#
#   lifecycle {
#     create_before_destroy = true
#   }
#   depends_on = [
#     module.dynamodb,
#     aws_instance.genai_service,
#     aws_instance.db_instance,
#     aws_instance.sentiment_service
#   ]
#
# }
#
# #Data block to fetch existing security group
# # data "aws_security_group" "existing_flask_sg" {
# #   filter {
# #     name   = "group-name"
# #     values = ["flask_sg"]
# #   }
# # }
#
# # Security group to allow inbound traffic to Flask. Use the existing security group if it exists
# resource "aws_security_group" "flask_sg" {
#   #count = try(data.aws_security_group.existing_flask_sg.id,"") != "" ? 0 : 1
#   name        = "flask_sg"
#   description = "Allow SSH, Flask, and DynamoDB Local"
#
#   # Allow HTTP traffic to Flask on port 5000
#   ingress {
#     from_port   = 5000
#     to_port     = 5000
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     from_port   = 5001
#     to_port     = 5001
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     from_port   = 5003
#     to_port     = 5003
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # Allow DynamoDB Local (port 8000)
#   ingress {
#     from_port   = 8000
#     to_port     = 8000
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # Allow SSH traffic on port 22
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # Allow all outbound traffic
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
#
# #Query for the existing security group
# # data "aws_security_group" "existing_db_instance_sg" {
# #   filter {
# #     name   = "group-name"
# #     values = ["db_instance_sg"]
# #   }
# # }
#
# # Security group for DB Instance
# resource "aws_security_group" "db_instance_sg" {
#   #count = try(data.aws_security_group.existing_db_instance_sg.id,"") != "" ? 0 : 1
#   name        = "db_instance_sg"
#   description = "Allow access from data-logic-instance only"
#
#   # Allow traffic from the data-logic-instance security group
#   ingress {
#     from_port   = 5002
#     to_port     = 5002
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     from_port       = 8000
#     to_port         = 8000
#     protocol        = "tcp"
#     security_groups = [local.flask_sg_id]
#   }
#
#   # Allow SSH for maintenance (optional)
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   # Allow all outbound traffic
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }




# ------------------------------------------------------- OUTPUTS ---------------------------------------------------




# output "dynamodb_tables" {
#   value = {
#     greetings_table = "greetings_table"
#     terraform_locks_table = "terraform_locks_table__ec2_branch"
#   }
# }
#
# output "security_group_ids" {
#   value = {
#     flask_sg_id      = local.flask_sg_id
#     db_instance_sg_id = local.db_instance_sg
#   }
#   description = "Security group IDs for Flask and DB instances."
# }
#
# output "service_ips" {
#   value = {
#     flask_ec2_public_ip           = aws_instance.flask_ec2.public_ip
#     genai_service_public_ip       = aws_instance.genai_service.public_ip
#     sentiment_service_public_ip   = aws_instance.sentiment_service.public_ip
#     dynamodb_service_public_ip    = aws_instance.db_instance.public_ip
#   }
#   description = "Public IPs of all microservices"
# }
#
# output "instance_names" {
#   value = {
#     data_logic_instance = aws_instance.flask_ec2.tags["Name"]
#     db_instance = aws_instance.db_instance.tags["Name"]
#   }
# }