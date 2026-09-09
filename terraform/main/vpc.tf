# Networking: 1 VPC, 2 public subnets across 2 AZs.
#
# No NAT Gateway — deliberate cost tradeoff (NAT alone runs ~$32/mo, blowing
# the ₹300/day cap). Every node gets a public IP; access is restricted purely
# via security groups (admin_cidr for SSH/kube-API, wide open only for
# HTTP/HTTPS via the NLB that Kong/AWS Load Balancer Controller creates later).

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project}-vpc"
    Project = var.project
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-igw"
    Project = var.project
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project}-public-${var.azs[count.index]}"
    Project = var.project
    # Tags AWS Load Balancer Controller looks for when auto-discovering
    # subnets to place the NLB in.
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-public-rt"
    Project = var.project
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
