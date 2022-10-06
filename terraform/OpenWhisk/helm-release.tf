provider "helm" {
  kubernetes {
    config_path = "${path.module}/../kubeconfig"
  }
}

variable "use_new_scheduler" {
  description = "If set to true, deploys Openwhisk with new scheduler (The new scheduler feature is still in development)"
  type        = bool
  default     = false
}

variable "use_custom_scheduler" {
  description = "If set to true, deploys Openwhisk with  our custom scheduler"
  type        = bool
  default     = false
}

resource "helm_release" "owdev" {
  count = var.use_custom_scheduler ? 0 : 1
  name       = "owdev"
  chart = var.use_new_scheduler ? "./openwhisk-chart-new-scheduler" : "./openwhisk-chart"
  namespace = kubernetes_namespace.openwhisk.id

  values = [
    var.use_new_scheduler ? file("${path.module}/OW-values-new-scheduler.yml") : file("${path.module}/OW-values.yml")
  ]
}

resource "helm_release" "owdev-custom-scheduler" {
  count = var.use_custom_scheduler ? 1 : 0
  name       = "owdev"
  chart = "./openwhisk-chart-custom-scheduler"
  namespace = kubernetes_namespace.openwhisk.id

  values = [
    file("${path.module}/OW-values-custom-scheduler.yml")
  ]
}