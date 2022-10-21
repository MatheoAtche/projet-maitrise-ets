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

variable "containerFactory" {
  description = "Choose the container factory to deploy (kubernetes or docker)"
  type        = string
  default     = "kubernetes"
  validation {
    condition     = contains(["kubernetes", "docker"], var.containerFactory)
    error_message = "The container factory to use must be one of kubernetes or docker."
  }
}

variable "prewarm" {
  description = "Deploy with prewarm containers or not"
  type        = bool
  default     = false
}

resource "helm_release" "owdev" {
  name = "owdev"
  chart = "./openwhisk-chart"
  namespace = kubernetes_namespace.openwhisk.id

  values = [
    file("${path.module}/OW-values-${var.scheduler}-scheduler.yml"),
  ]

  set {
    name = "invoker.containerFactory.impl"
    value = var.containerFactory
  }

  set {
    name = "whisk.runtimes"
    value = var.prewarm ? "runtimes-prewarm.json" : "runtimes.json"
  }
}