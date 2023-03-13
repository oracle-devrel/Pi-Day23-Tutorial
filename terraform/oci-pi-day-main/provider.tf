# Copyright (c) 2022 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

provider "oci" {
  region               = var.region
  tenancy_ocid         = var.tenancy_ocid
}


 terraform {
  required_version = ">= 1.1.0"

  required_providers {
    oci = {
      source                = "oracle/oci"
      version               = ">= 4.100.0"
    }
  }
} 