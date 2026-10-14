resource "aws_db_subnet_group" "postgres" {
  name = "${local.ecs_name}-postgres-subnet-group"

  subnet_ids = [
    aws_subnet.private_db_a.id,
    aws_subnet.private_db_c.id
  ]

  tags = {
    Name    = "${local.ecs_name}-postgres-subnet-group"
    Service = "postgresql"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.ecs_name}-postgres"

  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  db_name  = var.rds_database_name
  username = var.rds_master_username
  port     = 5432

  manage_master_user_password = true

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name = aws_db_subnet_group.postgres.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period  = var.rds_backup_retention_period
  copy_tags_to_snapshot    = true
  delete_automated_backups = true

  auto_minor_version_upgrade = true

  performance_insights_enabled = false
  deletion_protection          = false
  skip_final_snapshot          = true

  tags = {
    Name    = "${local.ecs_name}-postgres"
    Service = "postgresql"
  }
}