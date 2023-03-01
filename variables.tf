variable "region" {
  description = "The region in which VPC is creating."
 }

variable "vpc_name" {
  description = "The name of the VPC."
}

variable "vpc_cidr_block" {
  description = "The CIDR block range."
  }

variable "vpc_instance_tenancy" {
  default     = "default"
  }

variable "pub_sub_name" {
  description = "Public subnet name."
  }

variable "public_subnet_cidr_block" {
  description = "The CIDR block range of public subnet."
}

variable "public_subnet_AZ" {
  description = "Availability zones of public subnet."
    }

variable "InternetGw_name" {
  description = "The name of internet gateway."
  }

variable "Eip-name" {
  description = "The name of elastic IP."
  }

variable "Public_securitygrp" {
  description = "The name of security group."
  }

variable "instance_name1" {
  description = "instance name"
  }
variable "instance_name2" {
  description = "instance name"
  }

variable "ami_id" {
  description = "The ID of ami."
  }
variable "inst_type" {
 description = "instance type"
  }
variable "Eksclusterterra" {
  description= "IAM role for EKS cluster"
  }
variable "EKS_cluster_sgrp_priv" {
  description = "security group"
  }
variable "EKs_cluster_terra" {
  description = "cluster name"
  }
variable "Nodename"{
  description = "nodes name"
  }
variable "node_eksg" {
  description="node group name"
  }
