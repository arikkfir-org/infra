variable "project_id" {
  description = "GCP project that holds the domains' Cloud DNS zones and the hub's egress address (root gcp)."
  type        = string
  default     = "arikkfir"
}

variable "region" {
  description = "Region of the hub's egress address (root gcp)."
  type        = string
  default     = "me-west1"
}
