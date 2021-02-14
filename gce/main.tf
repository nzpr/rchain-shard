provider "google" {
  project	= var.project
  zone		= var.zone
  region	= var.region
  #credentials	= var.credentials_file
}

provider "google-beta" {
  project = var.project
  zone = var.zone
  region	= var.region
  #credentials	= var.credentials_file
}

terraform {
  required_version = ">= 0.12"
  backend "gcs" {
    bucket = "rchain-terraform-state"
    prefix = "shard"
  }
}

#############################################################
data "google_compute_network" "shard-network" {
  name = "default"
}

data "google_compute_subnetwork" "region-subnetwork" {
  name = "default"
  #network = data.google_compute_network.shard-network.self_link
  region = var.region
  #ip_cidr_range = var.subnet
}

resource "google_compute_firewall" "fw_public_node" {
  name = "${var.tag}-node-public"
  network = data.google_compute_network.shard-network.self_link
  priority = 530
  target_tags = ["${var.tag}-node"]
  allow {
    protocol = "tcp"
    ports = [22, 40403, 18080]
  }
}

resource "google_compute_firewall" "fw_public_node_rpc" {
  name = "${var.tag}-node-rpc"
  network = data.google_compute_network.shard-network.self_link
  priority = 540
  target_tags = ["${var.tag}-node"]
  allow {
    protocol = "tcp"
    ports = [40401]
  }
}

resource "google_compute_firewall" "fw_node_p2p" {
  name = "${var.tag}-node-p2p"
  network = data.google_compute_network.shard-network.self_link
  priority = 550
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["${var.tag}-node"]
  allow {
    protocol = "tcp"
    ports = [40400, 40404]
  }
}

resource "google_compute_firewall" "fw_node_deny" {
  name = "${var.tag}-node-deny"
  network = data.google_compute_network.shard-network.self_link
  priority = 5010
  target_tags = ["${var.tag}-node"]
  deny {
    protocol = "tcp"
  }
  deny {
    protocol = "udp"
  }
}

resource "google_compute_address" "node_ext_addr" {
  count = var.node_count
  name = "${var.tag}-node${count.index}-ext"
  address_type = "EXTERNAL"
}

resource google_compute_address "node_int_addr" {
  count = var.node_count
  name = "${var.tag}-node${count.index}-int"
  address_type = "INTERNAL"
  subnetwork = data.google_compute_subnetwork.region-subnetwork.self_link
  address = cidrhost(data.google_compute_subnetwork.region-subnetwork.ip_cidr_range, count.index + 10)
}

#resource "google_dns_record_set" "node_dns_record" {
#  count = var.node_count
#  name = "node${count.index}-${var.domain}."
#  managed_zone = "dev"
#  type = "A"
#  # make TTL small so cache won't mess up with restarts
#  ttl = 30
#  rrdatas = [google_compute_address.node_ext_addr[count.index].address]
#}

#############################################################
resource "google_compute_instance" "node_host" {
  count = var.node_count
  name = "node${count.index}-${var.tag}"
  hostname = "node${count.index}-${var.tag}.${var.domain}"
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      size = 100
      type = "pd-ssd"
    }
  }

  tags = [
    "${var.tag}-node",
    "collectd-out",
    "elasticsearch-out",
    "logstash-tcp-out",
    "logspout-http",
  ]

  network_interface {
    subnetwork = data.google_compute_subnetwork.region-subnetwork.self_link
    network_ip = google_compute_address.node_int_addr[count.index].address
    access_config {
      nat_ip = google_compute_address.node_ext_addr[count.index].address
    }
  }

  connection {
    type = "ssh"
    host = self.network_interface[0].access_config[0].nat_ip
    user = "root"
    private_key = file("~/.ssh/google_compute_engine")
  }

  provisioner "file" {
    source = "../node-files/node${count.index}.tar.gz"
    destination = "/root/rnode.tar.gz"
  }

  provisioner "file" {
    source = "../genesis_vaults.txt"
    destination = "/root/wallets.txt"
  }

  provisioner "file" {
    source = "../genesis_bonds.txt"
    destination = "/root/bonds.txt"
  }

  provisioner "remote-exec" {
    script = "../bootstrap.sh"
  }
}
