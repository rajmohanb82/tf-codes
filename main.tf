provider "aws" {
  region = "us-east-1"  # change this to your preferred AWS region
  access_key = var.aws_acces_key
  secret_key = var.aws_secret_key
}

resource "aws_instance" "ubuntu_instance" {
  ami           = "ami-0c7217cdde317cfec"  # replace with the latest Ubuntu 22.04 AMI in your region
  instance_type = "t3.medium"

  # Use an existing security group
  vpc_security_group_ids = ["sg-0dff307bf4b685399"]  # replace with your existing security group ID

  associate_public_ip_address = true  # enable public IP

  tags = {
    Name = "webserver"
  }
}
