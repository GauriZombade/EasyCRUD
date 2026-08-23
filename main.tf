terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.26.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# -----------------------------
# Get Default VPC
# -----------------------------

data "aws_vpc" "default" {
  default = true
}

# -----------------------------
# Get Default VPC Subnets
# -----------------------------

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -----------------------------
# EKS Cluster IAM Role
# -----------------------------

resource "aws_iam_role" "eks_cluster_role" {
  name = "cluster-2-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# -----------------------------
# EKS Cluster Policy
# -----------------------------

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------
# EKS Node IAM Role
# -----------------------------

resource "aws_iam_role" "node_role" {
  name = "cluster-2-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# -----------------------------
# Node Policies
# -----------------------------

resource "aws_iam_role_policy_attachment" "node_policies" {
  count = 3

  role = aws_iam_role.node_role.name

  policy_arn = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ][count.index]
}

# -----------------------------
# EKS Cluster
# -----------------------------

resource "aws_eks_cluster" "mycluster" {

  name     = "cluster-2"
  role_arn = aws_iam_role.eks_cluster_role.arn

  version = "1.35"

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids

    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# -----------------------------
# EKS Managed Node Group
# -----------------------------

resource "aws_eks_node_group" "nodegroup" {

  cluster_name = aws_eks_cluster.mycluster.name

  node_group_name = "default-node-group"

  node_role_arn = aws_iam_role.node_role.arn

  subnet_ids = data.aws_subnets.default.ids

  instance_types = ["c7i-flex.large"]

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policies
  ]
}

# -----------------------------
# Outputs
# -----------------------------

output "cluster_name" {
  value = aws_eks_cluster.mycluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.mycluster.endpoint
}