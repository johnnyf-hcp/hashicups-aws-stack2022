terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.8.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# create a keypair
# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "hashicups_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create the Key Pair
resource "aws_key_pair" "hashicups_key_pair" {
  key_name   = "hashicups-key-pair"
  public_key = tls_private_key.hashicups_key_pair.public_key_openssh
}
# Save PEM file locally
resource "local_file" "hashicups_ssh_key" {
  filename = "${aws_key_pair.hashicups_key_pair.key_name}.pem"
  content  = tls_private_key.hashicups_key_pair.private_key_pem
}

# Setting up a new agency VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name = "my-vpc"
  cidr = "10.100.0.0/16"
  azs  = ["ap-southeast-1a"]
  #private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = ["10.100.0.0/24"]

  #enable_nat_gateway = true
  #enable_vpn_gateway = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.prefix}-${var.environment}-hashicups"
    Owner       = "${var.prefix}"
    Environment = "${var.environment}"
  }
}

# Setting up EC2 instance role for SSM agent and CloudWatch Log agent
module "ssm_cwl_role" {
  source                = "Cloud-42/ec2-iam-role/aws"
  version               = "4.0.0"
  principal_type        = "Service"
  principal_identifiers = ["ec2.amazonaws.com"]

  name = "${var.prefix}-${var.environment}-hashicups-ec2-ssm-cwl-role"

  policy_arn = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
}


# Latest Amazon LINUX 2 AMI
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# limit SSH, RDP, HTTP and API (8080) ports to my IP
resource "aws_security_group" "hashicups-sg" {
  name   = "${var.prefix}-${var.environment}-hashicups-sg"
  vpc_id = module.vpc.vpc_id

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Web API HTTP access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name        = "${var.prefix}-${var.environment}-hashicups-sg"
    Owner       = "${var.prefix}"
    Environment = "${var.environment}"
  }
}

# Setting up HashiCups linux server
resource "aws_instance" "hashicups-docker-server" {
  ami                         = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  iam_instance_profile        = module.ssm_cwl_role.role.name
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashicups_key_pair.key_name
  vpc_security_group_ids      = ["${aws_security_group.hashicups-sg.id}"]
  subnet_id                   = module.vpc.public_subnets[0] # place into first public subnet
  user_data                   = templatefile("${path.module}/configs/deploy_app.tpl", {})

  tags = {
    Name        = "${var.prefix}-${var.environment}-hashicups-app"
    Owner       = "${var.prefix}"
    Environment = "${var.environment}"
  }
}

# Get latest Windows Server 2022 AMI
data "aws_ami" "windows-2022" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }
}

# Create a Windows EC2 Instance for SSM and Fleet Manager demo
resource "aws_instance" "windows-server" {
  ami                         = data.aws_ami.windows-2022.id
  associate_public_ip_address = true
  iam_instance_profile        = module.ssm_cwl_role.role.name
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashicups_key_pair.key_name
  vpc_security_group_ids      = ["${aws_security_group.hashicups-sg.id}"]
  subnet_id                   = module.vpc.public_subnets[0] # place into first public subnet


  tags = {
    Name        = "${var.prefix}-${var.environment}-demo-windows-server"
    Owner       = "${var.prefix}"
    Environment = "${var.environment}"
  }
}
