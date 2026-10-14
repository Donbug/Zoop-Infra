resource "aws_iam_role" "neo4j_ssm" {
  name = "${local.ecs_name}-neo4j-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${local.ecs_name}-neo4j-ssm-role"
    Service = "neo4j"
  }
}

resource "aws_iam_role_policy_attachment" "neo4j_ssm_core" {
  role       = aws_iam_role.neo4j_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "neo4j" {
  name = "${local.ecs_name}-neo4j-instance-profile"
  role = aws_iam_role.neo4j_ssm.name

  tags = {
    Name    = "${local.ecs_name}-neo4j-instance-profile"
    Service = "neo4j"
  }
}

resource "aws_instance" "neo4j" {
  ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  instance_type = var.neo4j_instance_type
  subnet_id     = aws_subnet.private_db_a.id

  vpc_security_group_ids = [
    aws_security_group.neo4j.id
  ]

  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.neo4j.name

  user_data                   = file("${path.module}/user_data/neo4j.sh")
  user_data_replace_on_change = true

  monitoring    = false
  ebs_optimized = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.neo4j_root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.neo4j_ssm_core
  ]

  tags = {
    Name    = "${local.ecs_name}-neo4j"
    Service = "neo4j"
  }
}

resource "aws_ebs_volume" "neo4j_data" {
  availability_zone = aws_subnet.private_db_a.availability_zone

  type      = "gp3"
  size      = var.neo4j_data_volume_size
  encrypted = true

  tags = {
    Name    = "${local.ecs_name}-neo4j-data"
    Service = "neo4j"
  }
}

resource "aws_volume_attachment" "neo4j_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.neo4j_data.id
  instance_id = aws_instance.neo4j.id
}