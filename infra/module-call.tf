module "network" {
  source = "./modules/network"
}

module "traffic_entry" {
  source = "./modules/traffic-entry"
}

module "database" {
  source = "./modules/database"
}

module "delivery" {
  source = "./modules/delivery"
}

module "security" {
  source = "./modules/security"
}

module "compute" {
  source = "./modules/compute"
}