terraform {
  backend "local" {
    path = "/state/terraform.tfstate"
  }
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    acme = {
      source = "terraform-providers/acme"
    }
  }
  required_version = ">= 0.13"
}

provider "acme" {
  #server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "digitalocean_api_token" {}
variable "email" {}

provider "digitalocean" {
  token = var.digitalocean_api_token
}

variable "domain" {
  default = "alfred.finance"
}

resource "tls_private_key" "bridge_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "digitalocean_ssh_key" "jump_key" {
  name = "jump key"
  public_key = tls_private_key.bridge_key.public_key_openssh
}

resource "digitalocean_droplet" "jump" {
  size = "s-1vcpu-1gb"
  image = "docker-20-04"
  name = "redirect-jump"
  region = "ams3"
  user_data = <<EOT
#cloud-config
runcmd:
  - sed -i -r -e "s/^\#?MaxSessions.*$/MaxSessions\ 100/" /etc/ssh/sshd_config
  - service ssh restart
  - ufw allow ssh
  - echo "${tls_private_key.bridge_key.public_key_openssh}" >> /root/.ssh/authorized_keys
EOT
  ssh_keys = [
    "f3:f8:60:4e:8f:f7:0b:e3:c6:45:e0:ca:08:38:c3:69",
    digitalocean_ssh_key.jump_key.fingerprint
  ]
}

variable "domain_record" {}

resource "digitalocean_record" "a-local-redirect-record" {
  domain = var.domain
  name = var.domain_record
  ttl = "30"
  type = "A"
  value = digitalocean_droplet.jump.ipv4_address
}

data "archive_file" "up_content" {
  type        = "zip"
  source_dir  = "up"
  output_path = ".up.zip"
}

output "bridge_ip" {
  value = digitalocean_droplet.jump.ipv4_address
}

resource "local_file" "private-ssh-key" {
  content = tls_private_key.bridge_key.private_key_pem
  filename = "private-ssh-key"
  file_permission = "0600"
}
data "local_file" "maintf" {
  filename = "main.tf"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {

  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.email
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = "${var.domain_record}.${var.domain}"
  subject_alternative_names = []

  dns_challenge {
    provider = "digitalocean"

    config = {
      DO_AUTH_TOKEN = var.digitalocean_api_token
      DO_POLLING_INTERVAL    = 15
      DO_PROPAGATION_TIMEOUT = 60
    }
  }
}

resource "null_resource" "jump_node" {

  triggers = {
    src_hash = data.archive_file.up_content.output_sha
    main_tf_hash = data.local_file.maintf.content
  }

  connection {
    host        = digitalocean_droplet.jump.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = tls_private_key.bridge_key.private_key_pem
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    connection {}
    inline = [
      "rm -rf /etc/docker-compose/*",
      "mkdir -p /etc/docker-compose",
      "mkdir -p /etc/docker-compose/certs",
    ]
  }

  provisioner "file" {
    source      = "./droplet/"
    destination = "/etc/docker-compose"
  }

  provisioner "file" {
    source      = "./main.tf"
    destination = "/etc/docker-compose/down/main.tf"
  }

  provisioner "file" {
    content = tls_private_key.bridge_key.public_key_openssh
    destination = "/etc/docker-compose/authorized_keys"
  }

  provisioner "file" {
    source      = "./droplet/setup.sh"
    destination = "/tmp/setup"
  }

  provisioner "file" {
    source      = "./droplet/docker-compose.service"
    destination = "/etc/systemd/system/docker-compose.service"
  }

  # caddy
  provisioner "file" {
    content = templatefile("./droplet/.tmpl.Caddyfile", {
      domain_record: var.domain_record,
      domain: var.domain
      digitalocean_api_token: var.digitalocean_api_token
    })
    destination = "/etc/docker-compose/Caddyfile"
  }

  provisioner "file" {
    source = "./droplet/docker-compose.yml"
    content = templatefile("./droplet/docker-compose.tmpl.yml", {
      digitalocean_api_token: var.digitalocean_api_token,
      domain_record: var.domain_record
    })
    destination = "/etc/docker-compose/docker-compose.yml"
  }

  #cert
  provisioner "file" {
    content     = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
    destination = "/etc/docker-compose/certs/certificate.pem"
  }

  provisioner "file" {
    content     = acme_certificate.certificate.private_key_pem
    destination = "/etc/docker-compose/certs/private_key.pem"
  }

  provisioner "file" {
    content     = acme_certificate.certificate.issuer_pem
    destination = "/etc/docker-compose/certs/issuer.pem"
  }

  # docker-compose
  provisioner "remote-exec" {
    connection {}
    inline = [
      "chmod +x /tmp/setup",
      "sudo /tmp/setup > /tmp/terraform_output.log",
    ]
  }

  depends_on = [
    digitalocean_droplet.jump
  ]
}