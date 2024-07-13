# Specify the provider
provider "aws" {
  variable "My_region" {
  description = "The My region to deploy the infrastructure"
  type        = string
  default     = "us-east-1"  # Default to North Virginia
}

# Create VPC
resource "my_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MainVPC"
  }
}

# Create Internet Gateway
resource "my_internet_gateway" "igw" {
  vpc_id = my_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

# Create Public Subnets
resource "my_subnet" "public_subnet_az1" {
  vpc_id            = my_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnetAZ1"
  }
}

resource "my_subnet" "public_subnet_az2" {
  vpc_id            = my_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnetAZ2"
  }
}

# Create Private Subnets
resource "my_subnet" "private_subnet_az1" {
  vpc_id            = my_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PrivateSubnetAZ1"
  }
}

resource "my_subnet" "private_subnet_az2" {
  vpc_id            = my_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "PrivateSubnetAZ2"
  }
}

# Create Elastic IPs for NAT Gateways
resource "my_eip" "nat_eip_az1" {
  vpc = true
}

resource "my_eip" "nat_eip_az2" {
  vpc = true
}

# Create NAT Gateways
resource "my_nat_gateway" "nat_gw_az1" {
  allocation_id = my_eip.nat_eip_az1.id
  subnet_id     = my_subnet.public_subnet_az1.id

  tags = {
    Name = "NatGatewayAZ1"
  }
}

resource "my_nat_gateway" "nat_gw_az2" {
  allocation_id = my_eip.nat_eip_az2.id
  subnet_id     = my_subnet.public_subnet_az2.id

  tags = {
    Name = "NatGatewayAZ2"
  }
}

# Create Route Tables
resource "my_route_table" "public_rt" {
  vpc_id = my_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = my_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "my_route_table" "private_rt_az1" {
  vpc_id = my_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = my_nat_gateway.nat_gw_az1.id
  }

  tags = {
    Name = "PrivateRouteTableAZ1"
  }
}

resource "my_route_table" "private_rt_az2" {
  vpc_id = my_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az2.id
  }

  tags = {
    Name = "PrivateRouteTableAZ2"
  }
}

# Associate Route Tables with Subnets
resource "my_route_table_association" "public_rt_association_az1" {
  subnet_id      = my_subnet.public_subnet_az1.id
  route_table_id = my_route_table.public_rt.id
}

resource "my_route_table_association" "public_rt_association_az2" {
  subnet_id      = my_subnet.public_subnet_az2.id
  route_table_id = my_route_table.public_rt.id
}

resource "my_route_table_association" "private_rt_association_az1" {
  subnet_id      = my_subnet.private_subnet_az1.id
  route_table_id = my_route_table.private_rt_az1.id
}

resource "my_route_table_association" "private_rt_association_az2" {
  subnet_id      = my_subnet.private_subnet_az2.id
  route_table_id = my_route_table.private_rt_az2.id
}

resource "my_autoscaling_group" "asg" {
  desired_capacity     = var.desired_capacity
  max_size             = var.max_size
  min_size             = var.min_size
  vpc_zone_identifier  = concat(my_subnet.public[*].id, my_subnet.private[*].id)
  launch_configuration = my_launch_configuration.lc.id

  tag {
    key                 = "Name"
    value               = "webserver"
    propagate_at_launch = true
  }
}

resource "my_launch_configuration" "lc" {
  name          = "example-lc"
  image_id      = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    create_before_destroy = true
  }
}

resource "my_elb" "web" {
  name               = "web-load-balancer"
  availability_zones = data.my_availability_zones.available.names

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = my_autoscaling_group.asg.instances[*].id
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

variable "desired_capacity" {
  description = "The desired capacity for the Auto Scaling group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "The maximum size for the Auto Scaling group"
  type        = number
  default     = 4
}

variable "min_size" {
  description = "The minimum size for the Auto Scaling group"
  type        = number
  default     = 1
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the EC2 instances"
  type        = string
  default     = "t2.micro"
}

