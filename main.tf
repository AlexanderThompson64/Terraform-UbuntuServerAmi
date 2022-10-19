provider "aws" {
  region     = "eu-west-2"
  access_key = ""
  secret_key = ""
}

#Create virtual private

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

#Create gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

#Create a route table

resource "aws_route_table" "main-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main"
  }
}

#Create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "value"
  }
}

#Associate a route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.main-route-table.id
}

#Create a security group

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_web"
  }
}

#Create a network interface

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#Assign public ip 

resource "aws_eip" "one" {
  vpc                       = true
  associate_with_private_ip = "10.0.1.50"
  network_interface         = aws_network_interface.test.id
  depends_on = [
    aws_internet_gateway.gw
  ]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

#Create Ubuntu Server
resource "aws_instance" "web-server-instance" {
  ami               = "ami-0f540e9f488cfa27d"
  instance_type     = "t2.micro"
  availability_zone = "eu-west-2a"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo your web server > /var/www/html/index.html"
                EOF

  tags = {
    Name = "web-server"
  }
}


