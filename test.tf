# Specify the provider
provider "aws" {
  region = "us-east-1" # North Virginia
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MainVPC"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnetAZ1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnetAZ2"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_subnet_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PrivateSubnetAZ1"
  }
}

resource "aws_subnet" "private_subnet_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "PrivateSubnetAZ2"
  }
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_az1" {
  vpc = true
}

resource "aws_eip" "nat_eip_az2" {
  vpc = true
}

# Create NAT Gateways
resource "aws_nat_gateway" "nat_gw_az1" {
  allocation_id = aws_eip.nat_eip_az1.id
  subnet_id     = aws_subnet.public_subnet_az1.id

  tags = {
    Name = "NatGatewayAZ1"
  }
}

resource "aws_nat_gateway" "nat_gw_az2" {
  allocation_id = aws_eip.nat_eip_az2.id
  subnet_id     = aws_subnet.public_subnet_az2.id

  tags = {
    Name = "NatGatewayAZ2"
  }
}

# Create Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table" "private_rt_az1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az1.id
  }

  tags = {
    Name = "PrivateRouteTableAZ1"
  }
}

resource "aws_route_table" "private_rt_az2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az2.id
  }

  tags = {
    Name = "PrivateRouteTableAZ2"
  }
}

# Associate Route Tables with Subnets
resource "aws_route_table_association" "public_rt_association_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_association_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rt_association_az1" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_rt_az1.id
}

resource "aws_route_table_association" "private_rt_association_az2" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_rt_az2.id
}

# Create Security Groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "PublicSG"
  }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PrivateSG"
  }
}

# Create Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]

  enable_deletion_protection = false

  tags = {
    Name = "AppLB"
  }
}

# Create Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "AppTG"
  }
}

# Create Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Launch Web Servers in Public Subnet
resource "aws_instance" "web_server" {
  count         = 2
  ami           = "ami-0b72821e2f351e396" # Example AMI
  instance_type = "t2.micro"
  subnet_id     = element([aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id], count.index)
  security_groups = [aws_security_group.public_sg.name]

  tags = {
    Name = "WebServer-${count.index}"
  }
}

# Launch App Servers in Private Subnet
resource "aws_instance" "app_server" {
  count         = 2
  ami           = "ami-0b72821e2f351e396" # Example AMI
  instance_type = "t2.micro"
  subnet_id     = element([aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id], count.index)
  security_groups = [aws_security_group.private_sg.name]

  tags = {
    Name = "AppServer-${count.index}"
  }
}

# Attach Web Servers to Target Group
resource "aws_lb_target"



