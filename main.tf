provider "aws" {
  region = var.region
}
resource "aws_vpc" "vpc_terra" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = var.vpc_name
  }
}
resource "aws_subnet" "Public_Subnet" {
  count      = length(var.public_subnet_cidr_block)
  vpc_id     = aws_vpc.vpc_terra.id
  cidr_block =var.public_subnet_cidr_block[count.index]
  availability_zone =var.public_subnet_AZ[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = var.pub_sub_name
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_terra.id

  tags = {
    Name = var.InternetGw_name
  }
}
resource "aws_route_table" "Public_RouteTable" {
  vpc_id = aws_vpc.vpc_terra.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public_RouteTable"
  }
}
resource "aws_route_table_association" "Subnet1" {
  count          = length(var.public_subnet_cidr_block)
  subnet_id      = aws_subnet.Public_Subnet.*.id[count.index]
  route_table_id = aws_route_table.Public_RouteTable.id
}
resource "aws_eip" "ElasticIP_new"{
  vpc = true
  tags = {
    Name = var.Eip-name
  }
} 

# Create the Security Group
resource "aws_security_group" "Public_SG" {
  vpc_id       = aws_vpc.vpc_terra.id
  name         = var.Public_securitygrp
  description  = "Security Group of Public EC2"

  # allow ingress of port 22
 ingress{ 
    description ="SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allow egress of all ports
 egress{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }  
  ingress {
   description       ="Custom"
   from_port         = 8080
   to_port           = 8080
   protocol          = "tcp"
   cidr_blocks       = ["0.0.0.0/0"]
  }
  tags = {
   Name = var.Public_securitygrp
  }
}
resource "aws_iam_role" "iam_EKS_Cluster"{
  name = var.Eksclusterterra
  assume_role_policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
   {
   "Effect": "Allow",
   "Principal": {
    "Service": "eks.amazonaws.com"
   },
   "Action": "sts:AssumeRole"
   }
  ]
 }
POLICY
}
 
resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.iam_EKS_Cluster.name}"
} 
resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.iam_EKS_Cluster.name}"
}
 
# Create security group for AWS EKS.
 
resource "aws_security_group" "EKSCluster_SG" {
  name        = var.EKS_cluster_sgrp_priv
# Use your VPC here
  vpc_id      = aws_vpc.vpc_terra.id 
 # Outbound Rule
  egress {                
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound Rule
  ingress {                
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
 
# Creating the AWS EKS cluster
 
resource "aws_eks_cluster" "EKSCluster_new" {
  name     = var.EKs_cluster_terra
  role_arn =  aws_iam_role.iam_EKS_Cluster.arn
  version  = "1.22"
 # Configure EKS with vpc and network settings 
  vpc_config {            
   security_group_ids = [aws_security_group.EKSCluster_SG.id]
# Configure subnets below
   subnet_ids         = "${aws_subnet.Public_Subnet.*.id}"
    }
  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy,
   ]
}
 
# Creating IAM role for AWS EKS nodes with assume policy so that it can assume 
 
resource "aws_iam_role" "Nodes_EKSCluster" {
  name = var.Nodename
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
 
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.Nodes_EKSCluster.name
}
 
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.Nodes_EKSCluster.name
}
 
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.Nodes_EKSCluster.name
}
 
# Create AWS EKS cluster node group
 
resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.EKSCluster_new.name
  node_group_name = var.node_eksg
  node_role_arn   = aws_iam_role.Nodes_EKSCluster.arn
  subnet_ids      = "${aws_subnet.Public_Subnet.*.id}"
  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 1
  }
 
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

# creating EFS
resource "aws_efs_file_system" "EFS" {
  creation_token = "EFS"
  encrypted      = true # (optional) enable encryption for EFS data
  lifecycle {
    # delete the EFS file system when Terraform is destroying the infrastructure
    prevent_destroy = false
  }
 tags = {
     Name = "EFS_new"
   }
 }
#Mounting EFS 


resource "aws_efs_mount_target" "efs-mount" {
   file_system_id  = "${aws_efs_file_system.EFS.id}"
   subnet_id = "${aws_subnet.Public_Subnet.id}
   security_groups = ["${aws_security_group.efs-sg.id}"]
}

resource "aws_security_group_rule" "efs-sg_ingress" {
  type        = "tcp"
  from_port   = 2049 # EFS port
  to_port     = 2049 # EFS port
  protocol    = "tcp"
  cidr_blocks = var.vpc_cidr_block
  security_group_id = aws_security_group.efs-sg
}
# defining AWS provisioner block
resource "kubernetes_persistent_volume" "efs_pv" {
  metadata {
    name = "efs1"
  }
  spec {
    capacity {
      storage = "1Gi"
    }
    access_modes = [
      "ReadWriteMany",
    ]
    persistent_volume_source {
      nfs {
        server = aws_efs_file_system.EFS.dns_name
        path   = "/"
      }
    }
  }
}
resource "kubernetes_persistent_volume_claim" "efs_pvc" {
  metadata {
    name = "efs1"
  }
  spec {
    access_modes = [
      "ReadWriteMany",
    ]
    resources {
      requests {
        storage = "1Gi"
      }
    }
  }
}
