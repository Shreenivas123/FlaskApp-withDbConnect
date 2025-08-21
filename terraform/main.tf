terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# VPC and networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "flask-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "flask-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "flask-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "flask-public-rt"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security groups
resource "aws_security_group" "ec2" {
  name   = "flask-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = {
    Name = "flask-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name   = "flask-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-rds-sg"
  }
}

# RDS subnet group
resource "aws_db_subnet_group" "default" {
  name       = "flask-rds-subnet-group"
  subnet_ids = [aws_subnet.public.id]

  tags = {
    Name = "flask-rds-subnet-group"
  }
}

# MySQL RDS instance
resource "aws_db_instance" "mysql" {
  identifier             = "flaskdb"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  username               = var.db_username
  password               = var.db_password
  db_name                = "mydb"
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "flask-mysql"
  }
}

# Fetch latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# EC2 instance to run Flask app
resource "aws_instance" "flask" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = "learnaws"

  user_data = <<-EOT
              #!/bin/bash
              dnf update -y
              dnf install -y git python3-pip
              cd /home/ec2-user
              git clone ${var.git_repo} app
              cd app
              pip3 install -r requirements.txt
              export DB_HOST=${aws_db_instance.mysql.address}
              export DB_USER=${var.db_username}
              export DB_PASS=${var.db_password}
              export DB_NAME=mydb
              nohup python3 app.py &
              EOT

  tags = {
    Name = "flask-ec2"
  }
}

output "ec2_public_ip" {
  value = aws_instance.flask.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}
