# SSH
resource "aws_key_pair" "vgh" {
  key_name   = "vgh"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAEAQCuW/klOclhy5P4ipa24ISqChtLrDsNOO/mSkmavq5ypE8LR9ZP2Y9o52LYZ+Cp3QTYO46qIt4ubTEnWHjaCoY82P2zyFn7S4X16NvKLnjRCV4T5U0O2MM8ZlQbQqZPvuzsNI64yMUWOlVKXGohWFctCxafQWzcFebctARf50armUPF9A7hKm0qYa6aEWl1/dtMs8JVP3+bhZ0AlhkbLNiOSvT63I9Yakc11bedmtY07nSVOa1bWgHuGogdbexqLeaKLj6xCQKKM1iM7uaxXZyJGXTXrFV+VomnWZ3WKRaGRU9ctf+ki3nJJpEphTQsir6Dvg/qXL6fOW1pU2vd5XgV60FVd6kvFzy5yMzZfRMrwgG4241BGtOrnNGJEqo/9HGSNv9xX7Mm0mqX57rdIagZPwGaOk930dI0osYuyv09o0tqzwtJByEQ8rzhHHVu1L1l7SrhcfGq2ocjyyuZ33AY4aIY3JaretsfyahhleHCXwJUSJS3NDob8sqg/h5OBEnWLEcWBUm5+L1EeK332LM9tBwxrqFu5h6FwUuUeg3GtmREbgAKfA8ZvUwN4bl/nGzxrwjBjC+Y1ceaU30IrcbxEl6KdmO2vxivtGUlzkjAZ7yg7VpPEGOFpOqfjpGF5QeWcFXD2fnF5pg+YwCQcKoC6fdyhndkKQDOA87uVkFhi3z/QFO/PJ4rNxx5N69cdtSwB4mwJIb5KtAsyciYZpsmV/YrZhNT/7pHuPl3gERUIDpw6roo7/Lkeb19WAOc+9fDEDyFvHJIzO6+J5Kt5YdG2eXMRcGsxSRAUhl3Hfbtfok3qNh86wp39xd1mjzRoslXSGTfARzNb/CjpLA7Bs7vcEHCVYqEOm4Po2irWQeZZPJqaf37TjThS9WesZQLxYsi1KvOJYQiIJeOK2JbccRlRTl0DmcKQbwhMPNdf87LzcsQpDzKE3iESMImmgmGu+zcx/lUwjs7zjAuC/nTbPXPfs5KzniCxJuHMjC08IoP4c+FnWXRwA8WjggqKWBom9gY8FfxnI35Ic/aZj4z2LSzBDISGxk50QwS44Z1RX5x/W28HmIk54BFl527/R0Z1UYodHK1/tLjIdPAAOiRHaTBzR/6jKqnvH5WTvzxOH1jclMtm0TLpTon+VgDwkPG1TRx5icTbyz1YtlEq3pfPRnE2endKJub52Tpiym9qbPVNDs0vK5JwExufUAplwtVUw35C+OVKUhIMYTHibpZZJnBKCuQCBZhQ/qGN13vuPHqhIVKkrsgdVabOj8QrPpbpQaoYDiaWCpLLKMDgt0VyOtpWJKksjUlzDF+nU7B37alXxc2wEVLHOqDvSze5RPdAiIrQUyWDf1GVtPcF9aABH1F vlad@ghn.me"
}

# Prometheus Instance
resource "aws_iam_instance_profile" "prometheus" {
  name = "prometheus"
  role = aws_iam_role.prometheus.name
}

data "aws_ami" "prometheus" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^Prometheus_.*"

  filter {
    name   = "tag:Group"
    values = ["vgh"]
  }

  filter {
    name   = "tag:Project"
    values = ["vgh"]
  }
}

resource "aws_eip" "prometheus" {
  vpc      = true
  instance = aws_instance.prometheus.id

  tags = merge(
    var.common_tags,
    {
      "Name" = "Prometheus"
    },
  )
}

data "null_data_source" "prometheus" {
  inputs = {
    public_dns = "ec2-${replace(join("", aws_eip.prometheus.*.public_ip), ".", "-")}.${data.aws_region.current.name == "us-east-1" ? "compute-1" : "${data.aws_region.current.name}.compute"}.amazonaws.com"
  }
}

resource "cloudflare_record" "prometheus" {
  zone_id = var.cloudflare_zone_id
  name    = "prometheus"
  value   = data.null_data_source.prometheus.outputs["public_dns"]
  type    = "CNAME"
}

resource "cloudflare_record" "wg" {
  zone_id = var.cloudflare_zone_id
  name    = "wg"
  value   = "prometheus.ghn.me"
  type    = "CNAME"
}

resource "aws_instance" "prometheus" {
  instance_type               = "t3.micro"
  ami                         = data.aws_ami.prometheus.id
  subnet_id                   = data.aws_subnet.primary.id
  vpc_security_group_ids      = [aws_security_group.prometheus.id]
  iam_instance_profile        = aws_iam_instance_profile.prometheus.name
  key_name                    = aws_key_pair.vgh.key_name
  associate_public_ip_address = true

  user_data = <<DATA
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo '*** Wait for other APT processes to finish'
# Because daily apt download activities are run at boot
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
  sleep 1
done

echo '*** Update APT'
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y update
sudo apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' --allow-remove-essential upgrade

echo '*** Set hostname'
sudo hostnamectl set-hostname prometheus.ghn.me

echo '*** Mount Data EBS'
sudo mkdir -p /data
echo '/dev/nvme1n1  /data  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
sudo mount -a

if [[ -d /data/wireguard ]]; then
  echo '*** Restore WireGuard config'
  sudo apt-get -qy install wireguard
  sudo mkdir -p /etc/wireguard
  echo '/data/wireguard  /etc/wireguard  none  defaults,bind  0  2' | sudo tee -a /etc/fstab
  sudo mount -a
  if [[ -s /etc/wireguard/wg0.conf ]]; then
    echo '*** Restart services'
    sudo systemctl start wg-quick@wg0
    sudo systemctl enable wg-quick@wg0
  fi
fi

if [[ -d /data/swarm ]]; then
  echo '*** Restore Swarm'
  sudo service docker stop
  sudo mkdir -p /var/lib/docker/swarm
  echo '/data/swarm  /var/lib/docker/swarm  none  defaults,bind  0  2' | sudo tee -a /etc/fstab
  sudo mount -a
  sudo service docker start

  echo '*** Reinitialize cluster'
  sudo docker swarm init --force-new-cluster --advertise-addr $(curl -s  http://169.254.169.254/latest/meta-data/local-ipv4)

  echo '*** Restart services'
  sudo service docker restart
fi

echo "FINISHED @ $(date "+%m-%d-%Y %T")" | sudo tee /var/lib/cloud/instance/deployed
DATA

  tags = merge(
    var.common_tags,
    {
      "Name" = "Prometheus"
    },
  )
}
