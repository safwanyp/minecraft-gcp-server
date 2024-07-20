variable "project_id" {
  description = "The GCP project ID"
}

variable "region" {
  description = "The region to deploy resources"
  default     = "asia-southeast1"
}

variable "zone" {
  description = "The zone to deploy resources"
  default     = "asia-southeast1-b"
}

variable "machine_type" {
  description = "The machine type for the Minecraft server"
  default     = "e2-highmem-2"
}
