resource "random_id" "name" {
  byte_length = 2
}

locals {
  name = "${var.name}-082521"
}

resource "ibm_resource_instance" "cos" {
  name              = "${local.name}-cos-instance"
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  resource_group_id = data.ibm_resource_group.project.id
  tags              = concat(var.tags, ["project:${var.name}", "deleteme:${formatdate("MMDDYYYY", timeadd(timestamp(), "96h"))}"])
}

resource "ibm_cos_bucket" "source" {
  count                = length(var.users)
  bucket_name          = "${local.name}-${var.users[count.index]}-source-bucket"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = "us-east"
  storage_class        = "standard"
}

resource "ibm_cos_bucket" "destination" {
  count                = length(var.users)
  bucket_name          = "${local.name}-${var.users[count.index]}-destination-bucket"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = "us-east"
  storage_class        = "standard"
}

resource "ibm_resource_key" "hmac" {
  count                = length(var.users)
  name                 = "${local.name}-${var.users[count.index]}-hmac-keys"
  resource_instance_id = ibm_resource_instance.cos.id
  parameters           = { "HMAC" = true }
  role                 = "Manager"
}
