module "gke_auth" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  depends_on   = [module.gke]
  project_id   = var.project_id
  location     = module.gke.location
  cluster_name = module.gke.name
}
resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "kubeconfig-${var.env_name}"
}
module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 2.5"
  project_id   = var.project_id
  network_name = "${var.network}-${var.env_name}"
  subnets = [
    {
      subnet_name   = "${var.subnetwork}-${var.env_name}"
      subnet_ip     = "10.10.0.0/16"
      subnet_region = var.region
    },
  ]
  secondary_ranges = {
    "${var.subnetwork}-${var.env_name}" = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "10.0.0.0/14"
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "10.4.0.0/19"
      },
    ]
  }
}

module "gke" {
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  project_id                      = var.project_id
  name                            = "${var.cluster_name}-${var.env_name}"
  regional                        = true
  enable_vertical_pod_autoscaling = "true"
  region                          = var.region
  network                         = module.gcp-network.network_name
  subnetwork                      = module.gcp-network.subnets_names[0]
  ip_range_pods                   = var.ip_range_pods_name
  ip_range_services               = var.ip_range_services_name
  http_load_balancing             = false
  horizontal_pod_autoscaling      = true
  network_policy                  = false
  enable_private_nodes            = true
  enable_private_endpoint         = false
  master_ipv4_cidr_block          = "10.32.0.0/28"
  master_authorized_networks = [
    {
      cidr_block   = "10.0.0.0/8",
      display_name = "all"
    },
    {
      cidr_block   = "66.182.195.139/32",
      display_name = "home"
    }
  ]


  node_pools = [
    {
      name               = "node-pool"
      machine_type       = var.machine_type
      min_count          = var.min_count
      max_count          = var.max_count
      node_locations     = "us-central1-a,us-central1-b"
      disk_size_gb       = var.disk_size_gb
      disk_type          = "pd-standard"
      image_type         = "COS"
      auto_repair        = true
      auto_upgrade       = true
      initial_node_count = 2
    },
  ]
}

