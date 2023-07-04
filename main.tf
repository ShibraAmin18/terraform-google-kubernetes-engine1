locals {
  region      = var.region
  project     = var.project
  environment = var.environment
}

provider "google" {
  region  = local.region
  project = local.project
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

# google_client_config and kubernetes provider must be explicitly specified like the following.
data "google_client_config" "default" {}

module "service_accounts_gke" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "~> 3.0"
  project_id = local.project
  prefix     = var.cluster_name
  names      = [local.environment]
  project_roles = [
    "${local.project}=>roles/monitoring.viewer",
    "${local.project}=>roles/monitoring.metricWriter",
    "${local.project}=>roles/logging.logWriter",
    "${local.project}=>roles/stackdriver.resourceMetadata.writer",
    "${local.project}=>roles/storage.objectViewer",
  ]
  display_name = format("%s-%s-gke-cluster Nodes Service Account", var.cluster_name, local.environment)
}

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  project_id                 = local.project
  name                       = format("%s-%s-gke-cluster", var.cluster_name, local.environment)
  region                     = local.region
  zones                      = var.zones
  network                    = var.vpc_name
  subnetwork                 = var.subnet
  ip_range_pods              = var.ip_range_pods_name
  ip_range_services          = var.ip_range_services_name
  release_channel            = var.release_channel
  kubernetes_version         = var.kubernetes_version
  http_load_balancing        = false
  horizontal_pod_autoscaling = true
  network_policy             = true
  enable_private_endpoint    = var.enable_private_endpoint
  enable_private_nodes       = var.enable_private_nodes
  # master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  create_service_account     = false
  remove_default_node_pool   = var.remove_default_node_pool
  master_authorized_networks = var.enable_private_endpoint ? [{ cidr_block = var.master_authorized_networks, display_name = "VPN IP" }] : []
  logging_service            = var.logging_service
  monitoring_service         = var.monitoring_service
  node_pools = [
    {
      name               = format("%s-%s-node-pool", var.default_np_name, local.environment)
      machine_type       = var.default_np_instance_type
      node_locations     = var.default_np_locations
      min_count          = var.default_np_min_count
      max_count          = var.default_np_max_count
      local_ssd_count    = 0
      disk_size_gb       = var.default_np_disk_size_gb
      enable_secure_boot = var.enable_secure_boot
      disk_type          = var.disk_type
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      preemptible        = var.default_np_preemptible
      initial_node_count = var.default_np_initial_node_count
      service_account    = module.service_accounts_gke.email
    },
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    all = {}

    format("%s-%s-node-pool", var.default_np_name, local.environment) = {
      "Infra-Services" = true
    }
  }

  node_pools_metadata = {
    all = {}
  }

  node_pools_taints = {
    all = []
  }

  node_pools_tags = {
    all = []
  }
}

