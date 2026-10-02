variable "keycloak_url" {
  description = "Keycloak's admin API: the in-cluster Service from the pipelines, a port-forward from a workstation."
  type        = string
  default     = "http://keycloak-service.keycloak.svc.cluster.local:8080"
}

variable "project_id" {
  description = "GCP project whose Secret Manager receives the generated client secrets."
  type        = string
  default     = "arikkfir"
}
