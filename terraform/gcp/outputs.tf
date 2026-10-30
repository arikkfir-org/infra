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

output "egress_ip" {
  description = "The one IP the hub's nodes and pods reach the internet from (Cloud NAT hub), for outside allow-lists."
  value       = google_compute_address.egress.address
}

output "artifact_registry_url" {
  description = "Docker repository URL (<url>/<image>:<tag>)."
  value       = google_artifact_registry_repository.images.registry_uri
}

output "octomaton_registry_url" {
  description = "Octomaton's public Docker repository URL (<url>/<image>:<tag>)."
  value       = google_artifact_registry_repository.octomaton.registry_uri
}

output "devhub_registry_url" {
  description = "DevHub's public Docker repository URL (<url>/<image>:<tag>)."
  value       = google_artifact_registry_repository.devhub.registry_uri
}

output "bucket_names" {
  description = "Buckets."
  value       = sort([for bucket in google_storage_bucket.this : bucket.name])
}

output "octomaton_dev_name_servers" {
  description = "Name servers of octomaton.dev's zone, which root namecheap sets at Namecheap."
  value       = google_dns_managed_zone.this["octomaton-dev"].name_servers
}

output "cobranch_dev_name_servers" {
  description = "Name servers of cobranch.dev's zone, which root namecheap sets at Namecheap."
  value       = google_dns_managed_zone.this["cobranch-dev"].name_servers
}

output "cobranch_app_name_servers" {
  description = "Name servers of cobranch.app's zone, which root namecheap sets at Namecheap."
  value       = google_dns_managed_zone.this["cobranch-app"].name_servers
}
