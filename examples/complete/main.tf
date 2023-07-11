locals {
  region       = "asia-south1"
  environment  = "dev"
  name         = "org"
  project_name = "abc-12345678"
}

module "gke" {
  source                     = "./terraform-google-kubernetes-engine"
  project                    = local.project_name
  cluster_name               = local.name
  region                     = local.region
  environment                = local.environment
  zones                      = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]
  vpc_name                   = "dev-vpc"
  subnet                     = "dev-subnet-1"
  kubernetes_version         = "1.25"
  enable_private_endpoint    = true
  master_authorized_networks = [""]
  default_np_instance_type   = "e2-medium"
  default_np_locations       = "asia-south1-a,asia-south1-b"
  default_np_max_count       = 5
  default_np_preemptible     = true

}


module "managed_node_pool" {
  source             = "./modules/node-pool"
  depends_on         = [module.gke]
  project            = local.project
  cluster_name       = module.gke.name
  name               = "app"
  environment        = local.environment
  location           = local.region
  kubernetes_version = "1.25"
  service_account    = module.gke.service_accounts_gke
  initial_node_count = 1
  min_count          = 1
  max_count          = 5
  node_locations     = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]
  preemptible        = true
  instance_type      = "e2-medium"
  disk_size_gb       = 50
  labels = {
    "App-services" : true
  }
}
