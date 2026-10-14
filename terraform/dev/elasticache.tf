resource "aws_elasticache_subnet_group" "valkey" {
  name = "${local.ecs_name}-valkey-subnet-group"

  subnet_ids = [
    aws_subnet.private_db_a.id,
    aws_subnet.private_db_c.id
  ]

  tags = {
    Name    = "${local.ecs_name}-valkey-subnet-group"
    Service = "valkey"
  }
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id = "${local.ecs_name}-valkey"
  description          = "Valkey cache for ${local.ecs_name}"

  engine         = "valkey"
  engine_version = var.valkey_engine_version
  node_type      = var.valkey_node_type
  port           = var.valkey_port

  cluster_mode               = "disabled"
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  subnet_group_name = aws_elasticache_subnet_group.valkey.name

  security_group_ids = [
    aws_security_group.redis.id
  ]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = {
    Name    = "${local.ecs_name}-valkey"
    Service = "valkey"
  }
}