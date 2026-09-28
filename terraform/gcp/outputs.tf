output "cluster_name" {
  description = "Name of the hub GKE cluster."
  value       = google_container_cluster.hub.name
}

output "cluster_location" {
  description = "Zone of the hub GKE cluster."
  value       = google_container_cluster.hub.location
}

output "cluster_dns_endpoint" {
  description = "DNS-based control plane endpoint (the only one enabled)."
  value       = google_container_cluster.hub.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "ingress_protected_ip" {
  description = "Load balancer IP of the Traefik protected gateway."
  value       = google_compute_address.ingress["protected"].address
}

output "ingress_public_ip" {
  description = "Load balancer IP of the Traefik public gateway."
  value       = google_compute_address.ingress["public"].address
}

output "artifact_registry_url" {
  description = "Docker repository URL (<url>/<image>:<tag>)."
  value       = google_artifact_registry_repository.images.registry_uri
}

output "bucket_names" {
  description = "Public buckets."
  value       = sort([for bucket in google_storage_bucket.public : bucket.name])
}
