# Get all the Availability Domains for the region and default backup policies
data "oci_identity_availability_domain" "ad" {
  compartment_id  = var.compartment_ocid
  ad_number       = 1
}

# Select the latest Oracle Linux 8 image
data "oci_core_images" "ol8_images" {
    compartment_id = var.compartment_ocid
    shape = var.instance_shape
    operating_system = "Oracle Linux"
    operating_system_version = "8"
    sort_by = "TIMECREATED"
    sort_order = "DESC"
}

# Create Virtual Cloud Network (VCN)
resource "oci_core_vcn" "vcn" {
  cidr_block      = var.vcn_cidr
  dns_label       = var.label_prefix
  compartment_id  = var.compartment_ocid
  display_name    = var.vcn_name
}

# Create Internet Gaeway
resource "oci_core_internet_gateway" "igw" {
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_vcn.vcn.id
  display_name    = "${var.label_prefix}-igw}"
}

# Create Route Table
resource "oci_core_route_table" "rt_via_igw" {
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_vcn.vcn.id
  display_name    = "${var.label_prefix}-pubRT}"
  route_rules {
    destination       = local.anywhere
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Create Security List to allow ingress traffic for port 80 and 22
resource "oci_core_security_list" "SecList" {
  compartment_id = var.compartment_ocid
  display_name   = "AppSecList"
  vcn_id         = oci_core_vcn.vcn.id
  egress_security_rules {
    description       = "Allow all outbound traffic"
    protocol          = local.all_protocols
    destination       = local.anywhere
    destination_type  = "CIDR_BLOCK"
  }
  ingress_security_rules {
    description       = "Ingress traffic for HTTP, port 80"
    tcp_options {
      min = local.http_port
      max = local.http_port
    }
    protocol          = local.tcp_protocol
    source            = local.anywhere
    source_type       = "CIDR_BLOCK"
  }

  ingress_security_rules {
    description       = "Ingress traffic for SSH, port 22"
    tcp_options {
      min = local.ssh_port
      max = local.ssh_port
    }
    protocol          = local.tcp_protocol
    source            = local.anywhere
    source_type       = "CIDR_BLOCK"
  }
}

# Create subnet
resource "oci_core_subnet" "Subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn.id
  cidr_block                 = local.subnet_cidr
  display_name               = "${var.label_prefix}-pubSub01"
  dns_label                  = var.label_prefix
  route_table_id             = oci_core_route_table.rt_via_igw.id
  security_list_ids          = [oci_core_security_list.SecList.id]
}

# Create Compute Instance
resource "oci_core_instance" "compute_server" {
  count               = 1
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "${var.label_prefix}_server_${count.index}"
  shape               = var.instance_shape

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  shape_config {
    ocpus         = var.instance_shape_config_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.Subnet.id
    display_name              = "${var.label_prefix}-server-${count.index}"
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = "${var.label_prefix}-server-${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ol8_images.images[0].id
  }

  timeouts {
    create = "60m"
  }
}

output "instance_public_ip" {
  description     = "Public IP of the compute resource"
  value           = oci_core_instance.compute_server[0].public_ip 
}