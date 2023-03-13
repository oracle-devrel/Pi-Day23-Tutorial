variable "region" {
  # List of regions: https://docs.cloud.oracle.com/iaas/Content/General/Concepts/regions.htm#ServiceAvailabilityAcrossRegions
  description = "the OCI region where resources will be created"
  type        = string
  default     = null
}

variable "tenancy_ocid" {
  description = "the tenancy OCID"
}

variable "vcn_name" {
  description = "user-friendly name of to use for the vcn to be appended to the label_prefix"
  type        = string
  default     = "PiDay23-VCN"
  validation {
    condition     = length(var.vcn_name) > 0
    error_message = "The vcn_name value cannot be an empty string."
  }
}

variable "label_prefix" {
  description = "piday23"
  default     = "piday23"
}

variable "vcn_cidr" {
  description = "The list of IPv4 CIDR blocks the VCN will use."
  default     = "10.0.0.0/16"
}

variable "compartment_ocid" {
  description = "Set the compartment OCID"
}

variable "ssh_public_key" {
  description = "Public key for accessing the compute instance"
}

variable "instance_shape" {
  description = "Compute Instance Shape - VM.Standard.A1.Flex"
  default     = "VM.Standard.A1.Flex"
}

variable "instance_shape_config_ocpus" {
  description = "Number of OCPUs to assign to the compute instance"
  default     = 4
}

variable "instance_shape_config_memory_in_gbs" {
  description = "Amount of RAM to allocate to the compute instance"
  default     = 12
}

locals {
  tcp_protocol      = "6"
  udp_protocol      = "17"
  all_protocols     = "all"
  anywhere          = "0.0.0.0/0"
  ssh_port          = "22"
  http_port         = "80"
  https_port        = "443"
  subnet_cidr   = cidrsubnet(var.vcn_cidr, 8, 30)
}
