resource "aws_security_group" "task" {
  for_each    = toset(["reader", "stage", "operator"])
  name        = "${local.name}-${each.key}-sg"
  description = "Isolated operational69 ${each.key} tasks"
  vpc_id      = data.aws_vpc.existing.id
  tags        = { Name = "${local.name}-${each.key}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "reader" {
  security_group_id            = aws_security_group.task["reader"].id
  referenced_security_group_id = aws_security_group.task["operator"].id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

resource "aws_vpc_security_group_egress_rule" "reader_http" {
  security_group_id            = aws_security_group.task["operator"].id
  referenced_security_group_id = aws_security_group.task["reader"].id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

resource "aws_vpc_security_group_ingress_rule" "efs" {
  for_each                     = aws_security_group.task
  security_group_id            = var.existing.efs_security_group
  referenced_security_group_id = each.value.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
}

resource "aws_vpc_security_group_egress_rule" "efs" {
  for_each                     = aws_security_group.task
  security_group_id            = each.value.id
  referenced_security_group_id = var.existing.efs_security_group
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = var.existing.rds_security_group
  referenced_security_group_id = aws_security_group.task["operator"].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "database" {
  security_group_id            = aws_security_group.task["operator"].id
  referenced_security_group_id = var.existing.rds_security_group
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Existing NAT and S3 gateway paths deliver images, logs and secrets; HTTPS is not external network denial.
resource "aws_vpc_security_group_egress_rule" "https" {
  for_each          = aws_security_group.task
  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
