# Prometheus Subnets
data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "primary" {
  id = sort(data.aws_subnet_ids.public.ids)[0]
}

# Prometheus Instance Security Group
resource "aws_security_group" "prometheus" {
  name        = "Prometheus"
  description = " Prometheus Security Group"
  vpc_id      = var.vpc_id

  tags = var.common_tags
}

resource "aws_security_group_rule" "prometheus_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.prometheus.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "prometheus_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.prometheus.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "prometheus_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.prometheus.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "prometheus_ping" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  security_group_id = aws_security_group.prometheus.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "prometheus_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.prometheus.id
  source_security_group_id = aws_security_group.prometheus.id
}

resource "aws_security_group_rule" "prometheus_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.prometheus.id
  cidr_blocks       = ["0.0.0.0/0"]
}
