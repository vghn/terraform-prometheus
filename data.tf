# Prometheus Data Volume
resource "aws_ebs_volume" "prometheus_data" {
  availability_zone = "us-east-1a"
  type              = "gp2"
  encrypted         = true

  tags = merge(
    var.common_tags,
    {
      "Name"     = "Prometheus Data"
      "Snapshot" = "true"
    },
  )
}

resource "aws_volume_attachment" "prometheus_data_attachment" {
  device_name  = "/dev/sdg"
  instance_id  = aws_instance.prometheus.id
  volume_id    = aws_ebs_volume.prometheus_data.id
  skip_destroy = true
}
