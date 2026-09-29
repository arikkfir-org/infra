variable "octomaton_app_id" {
  description = "App ID of the Octomaton GitHub App. When set, the required `ci` check must come from that App; null accepts it from any source."
  type        = number
  nullable    = true
  default     = null
}
