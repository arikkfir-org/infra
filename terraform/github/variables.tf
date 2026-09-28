variable "octomaron_app_id" {
  description = "App ID of the octomaron GitHub App. When set, the required `ci` check must come from that App; null accepts it from any source."
  type        = number
  nullable    = true
  default     = null
}
