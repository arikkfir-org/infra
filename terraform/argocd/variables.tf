variable "project_id" {
  description = "GCP project of the hub cluster."
  type        = string
  default     = "arikkfir"
}

variable "cluster_name" {
  description = "Name of the hub GKE cluster (created by terraform/gcp)."
  type        = string
  default     = "hub"
}

variable "cluster_location" {
  description = "Zone of the hub GKE cluster."
  type        = string
  default     = "me-west1-a"
}
