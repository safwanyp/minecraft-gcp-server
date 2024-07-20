provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "minecraft_network" {
  name                    = "minecraft-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "minecraft_subnet" {
  name          = "minecraft-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.minecraft_network.id
}

resource "google_compute_firewall" "minecraft_firewall" {
  name    = "minecraft-firewall"
  network = google_compute_network.minecraft_network.name

  allow {
    protocol = "tcp"
    ports    = ["25565"]  # Minecraft server port
  }

  allow {
    protocol = "tcp"
    ports    = ["8000"]   # Crafty Controller web interface port
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_disk" "minecraft_data" {
  name = "minecraft-data"
  type = "pd-ssd"
  zone = var.zone
  size = 50  # GB
}

resource "google_compute_instance" "minecraft_server" {
  name         = "minecraft-server"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-20.04-lts"
      size  = 20  # GB
    }
  }

  attached_disk {
    source      = google_compute_disk.minecraft_data.self_link
    device_name = "minecraft-data"
  }

  network_interface {
    network    = google_compute_network.minecraft_network.name
    subnetwork = google_compute_subnetwork.minecraft_subnet.name
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = file("${path.module}/startup_script.sh")

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_storage_bucket" "minecraft_backups" {
  name     = "${var.project_id}-minecraft-backups"
  location = var.region
  force_destroy = true
}

output "minecraft_server_ip" {
  value = google_compute_instance.minecraft_server.network_interface[0].access_config[0].nat_ip
}

output "backup_bucket_name" {
  value = google_storage_bucket.minecraft_backups.name
}
