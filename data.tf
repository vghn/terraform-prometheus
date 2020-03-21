# Prometheus Data Volume
data "aws_instance" "prometheus" {
  instance_id = aws_instance.prometheus.id
}

resource "aws_ebs_volume" "prometheus_data" {
  availability_zone = data.aws_subnet.primary.availability_zone
  type              = "gp2"
  encrypted         = true
  size              = 10

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
