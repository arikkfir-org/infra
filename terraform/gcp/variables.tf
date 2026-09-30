variable "project_id" {
  description = "GCP project that hosts the hub."
  type        = string
  default     = "arikkfir"
}

variable "project_number" {
  description = "Number of the GCP project; used in Workload Identity Federation principal identifiers."
  type        = string
  default     = "8909046976"
}

variable "region" {
  description = "Region for the network, static IPs, Artifact Registry and buckets."
  type        = string
  default     = "me-west1"
}

variable "zone" {
  description = "Zone of the (zonal) GKE cluster control plane and of the system node pool."
  type        = string
  default     = "me-west1-a"
}

variable "domain" {
  description = "Hub DNS domain; its Cloud DNS zone is named after it with dots replaced by dashes."
  type        = string
  default     = "kfirs.com"
}

variable "cidrs" {
  description = "Primary range of the hub subnet (nodes) and its secondary ranges for GKE Pods and Services."
  type = object({
    nodes    = string
    pods     = string
    services = string
  })
  default = {
    nodes    = "10.10.0.0/20"
    pods     = "10.20.0.0/16"
    services = "10.30.0.0/20"
  }
}

variable "system_pool" {
  description = "Machine type and autoscaling bounds (total nodes) of the on-demand system node pool."
  type = object({
    machine_type = string
    min_nodes    = number
    max_nodes    = number
  })
  default = {
    machine_type = "e2-standard-4"
    min_nodes    = 1
    max_nodes    = 3
  }
}

variable "ci_pool" {
  description = "Machine type and autoscaling bounds (total nodes across its zones) of the Spot CI node pool."
  type = object({
    machine_type = string
    min_nodes    = number
    max_nodes    = number
  })
  default = {
    machine_type = "e2-standard-4"
    min_nodes    = 0
    max_nodes    = 4
  }
}
