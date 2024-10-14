## S3 BUCKET ##
resource "random_string" "random" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_s3_bucket" "bucket" {
  bucket = "falcon-iac-bucket-${random_string.random}"
  acl    = "public-read-write"  ## Change this to private

  server_side_encryption_configuration = {
    rule = {
        apply_server_side_encryption_by_default = {
            sse_algorithm     = "AES256"
        bucket_key_enabled = true
      }
    }
  }
}

## VPC ##
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "falcon-iac-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "falcon-iac-igw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc      = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.private_subnet.id

  tags = {
    Name = "falcon-iac-nat"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "falcon-iac-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "falcon-iac-private-subnet"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "falcon-iac-public-rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat.id
  }

  tags = {
    Name = "falcon-iac-private-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

## EC2 ##

data "aws_ami" "ami" {
  most_recent = true
  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  owners = ["amazon"]
}

resource "aws_instance" "instance_a" {
  ami                         = data.aws_ami.ami.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.arn
  associate_public_ip_address = true  ## Change this to false

  tags = {
    Name = "falcon-iac-instance-a"
  }
}

resource "aws_instance" "instance_b" {
  ami                         = data.aws_ami.ami.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_subnet.id
  associate_public_ip_address = false

  tags = {
    Name = "falcon-iac-instance-b"
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "test_profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "test_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "role_policy" {
  name = "test_policy"
  role = aws_iam_role.role.id

  ## Change "*" in Resource to "${aws_s3_bucket.bucket.arn}"
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

## Secret ##

variable "secret_var" {
 sensitive = true
 default   = "example"
}

resource "aws_secretsmanager_secret_version" "secret_value" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = var.secret_var
}

resource "aws_secretsmanager_secret" "secret" {
  name = "falcon-iac-secret"
}