provider "helm" {
  kubernetes {
    config_path = "${path.module}/../kubeconfig"
  }
}

variable "scheduler" {
  description = "Choose the scheduler to deploy (default, new or custom)"
  type        = string
  default     = "default"
  validation {
    condition     = contains(["default", "new", "custom"], var.scheduler)
    error_message = "The scheduler to use must be one of default, new or custom."
  }
}

resource "helm_release" "owdev" {
  name = "owdev"
  chart = "./openwhisk-chart"
  namespace = kubernetes_namespace.openwhisk.id

  values = [
    file("${path.module}/OW-values-${var.scheduler}-scheduler.yml")
  ]
}