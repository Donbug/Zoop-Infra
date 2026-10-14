#!/bin/bash

set -euxo pipefail

exec > >(tee /var/log/neo4j-user-data.log | logger -t neo4j-user-data -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y docker

systemctl enable --now docker
systemctl enable --now amazon-ssm-agent || true

usermod -aG docker ec2-user

mkdir -p /opt/neo4j
chown ec2-user:ec2-user /opt/neo4j

docker --version
systemctl status docker --no-pager