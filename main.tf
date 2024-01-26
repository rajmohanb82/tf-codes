provider "aws" {
  region = "us-east-1"  # change this to your preferred AWS region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}
# Create VPC
resource "aws_vpc" "uipath_vpc" {
  cidr_block = "192.110.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
tags = {
    Name = "UiPath_VPC"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "uipath_igw" {
  vpc_id = aws_vpc.uipath_vpc.id

  tags = {
    Name = "UiPath_IGW"
  }
}

# Create Public Subnet
resource "aws_subnet" "uipath_subnet" {
  vpc_id                  = aws_vpc.uipath_vpc.id
  cidr_block              = "192.110.1.0/24"  # Adjust the CIDR block for your subnet
  availability_zone       = "us-east-1a"  # Specify the desired availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "UiPath_Subnet"
  }
}

# Create Route Table
resource "aws_route_table" "uipath_route_table" {
  vpc_id = aws_vpc.uipath_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.uipath_igw.id
  }

  tags = {
    Name = "UiPath_Route_Table"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "uipath_subnet_association" {
  subnet_id      = aws_subnet.uipath_subnet.id
  route_table_id = aws_route_table.uipath_route_table.id
}

resource "aws_instance" "uipath_instance" {
  ami           = "ami-023c11a32b0207432"  # Replace with the appropriate AMI ID for Red Hat Linux
  instance_type = "m5.2xlarge"  # Replace with the desired instance type
  key_name      = "lx-key-openssh"  # Replace with your key pair name
  subnet_id      = aws_subnet.uipath_subnet.id
root_block_device {
    volume_size = 20  # Adjust the root volume size as needed
  }

ebs_block_device {
    device_name = "/dev/sdb"
    volume_type = "gp3"  # You can change to "io1" for provisioned IOPS
    volume_size = 50
    delete_on_termination = true
}
ebs_block_device {
    device_name = "/dev/sdc"
    volume_type = "gp3"  # You can change to "io1" for provisioned IOPS
    volume_size = 16
    delete_on_termination = true
  }
  tags = {
    Name = "UiPath_Instance"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo -s",
      "sudo yum update -y",
      "sudo yum install -y unzip",  # UiPath may require additional dependencies",
      "sudo curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2022.repo",
      "sudo yum install -y mssql-server",
      "systemctl status mssql-server",
      "curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/mssql-release.repo",
      "mkdir -p /opt/UiPathAutomationSuite",
      "chmod -R 755 /opt/UiPathAutomationSuite",
      "mkdir -p /uipath/tmp",
      "cd /uipath/tmp",
      # Add any other necessary pre-installation steps here
      "wget -O ~/installUiPathAS.sh https://download.uipath.com/automation-suite/2023.4.3/installUiPathAS.sh",
      "wget -O ~/as-installer.zip https://download.uipath.com/automation-suite/2023.4.3/installer-2023.4.3.zip",
      "mv /uipath/tmp/installUiPathAS.sh /uipath/tmp/as-installer.zip /opt/UiPathAutomationSuite",
      "cd /opt/UiPathAutomationSuite",
      "unzip ./as-installer.zip -d .",
      "chmod +x ./bin/jq",
      # Add any necessary installation commands specific to UiPath
      # For example, if UiPath provides a script for installation, execute it here
      "chmod -R 755 /opt/UiPathAutomationSuite"
    ]
    connection {
      host = self.public_ip
      type        = "ssh"
      user        = "ec2-user"  # Change this if using a different user for your AMI
      private_key = file("lx-key-openssh.pem")
    }
  }
}

output "instance_public_ip" {
  value = aws_instance.uipath_instance.public_ip
}
