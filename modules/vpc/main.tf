resource "aws_vpc" "dev" {
  cidr_block = var.vpccidr
  tags = {
    Name = "tors"
  }
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = var.subcidr
  availability_zone = var.zone
  tags = {
    Name = "sub"
  }
}

resource "aws_internet_gateway" "int" {
  vpc_id = aws_vpc.dev.id
  tags = {
    Name = "inget"
  }
}

resource "aws_route_table" "rou" {
  vpc_id = aws_vpc.dev.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int.id
  }
}

resource "aws_route_table_association" "soc" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rou.id
}