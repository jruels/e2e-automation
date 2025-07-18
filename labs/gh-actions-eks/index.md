# GitHub Actions EKS CI/CD Pipeline

## Overview

This hands-on lab teaches you how to implement a complete CI/CD pipeline for deploying and managing an Amazon EKS cluster using GitHub Actions and Terraform. You'll learn real-world DevOps practices including:

- Infrastructure as Code (IaC) with Terraform
- CI/CD automation with GitHub Actions
- Container orchestration with Amazon EKS
- Security best practices with secrets management
- Environment-based deployment approvals

By the end of this lab, you'll have a production-ready CI/CD pipeline that can automatically provision, update, and destroy an EKS cluster with proper security controls and approval workflows.

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed and configured
- Git installed and configured
- GitHub account with access to create repositories
- Basic understanding of Kubernetes, Terraform, and GitHub Actions

---

## Part 1: Initial Setup and Configuration

### Create a New Repository

1. **Go to GitHub.com** and sign in to your account
2. **Click the "+" icon** in the top right corner
3. **Select "New repository"**
4. **Configure your repository**:
   - Repository name: `gh-actions-eks`
   - Description: `End-to-End Automation Lab with GitHub Actions and EKS`
   - Make it **Public** (for easier collaboration)
   - Check "Add a README file"
   - Check "Add .gitignore" and select "Terraform"
   - Leave "Choose a license" as "None"
5. **Click "Create repository"**

---

## Part 2: AWS and GitHub Configuration

### Add GitHub Repository Secrets

Your AWS credentials are already configured locally, but GitHub Actions needs access to deploy to AWS.

1. Go to your forked repository's Settings
2. Click "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Add the following secrets:
   ```
   Name: AWS_ACCESS_KEY_ID
   Value: (your AWS access key)
   
   Name: AWS_SECRET_ACCESS_KEY
   Value: (your AWS secret key)
   ```

> **Security Note**: In production environments, use IAM roles for service accounts (IRSA) instead of long-term access keys.

### Create GitHub Environment

GitHub Environments provide deployment protection rules and approval workflows:

1. Go to repository Settings → Environments
2. Click "New environment"
3. Name it: `gh-actions-lab`
4. Enable "Required reviewers"
5. Add your GitHub username as a required reviewer
6. Save protection rules

This ensures that infrastructure changes require manual approval before deployment.

---

## Part 3: AWS S3 Backend Configuration

### Create S3 Bucket for Terraform State

Terraform state files contain sensitive information and should be stored securely in a remote backend.

1. Log into AWS Console
2. Navigate to S3 service
3. Click "Create bucket"
4. Create a globally unique bucket name (e.g., `terraform-state-eks-lab-YOUR-USERNAME-123`)
5. Region: `us-west-1`
6. Enable versioning for state file history
7. Enable default encryption
8. Block all public access
9. Click "Create bucket"

> **Important**: Remember your bucket name - you'll need it in the next step.

---

## Part 4: Repository Configuration

### Clone Repository Using VS Code

1. **Open Visual Studio Code**
2. **Clone Repository using VS Code GUI**:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) to open Command Palette
   - Type `Git: Clone` and select it
   - Enter your repository URL: `https://github.com/YOUR-USERNAME/gh-actions-eks.git`
   - Choose a local folder to clone into
   - Click "Open" when VS Code asks to open the cloned repository

### Create Feature Branch using VS Code

1. **Create a Branch using VS Code GUI**:
   - Look at the bottom-left status bar for the current branch name (likely "main")
   - Click on the branch name in the status bar
   - Select "Create new branch..."
   - Enter branch name: `feature/eks-deployment`
   - Press Enter to create and switch to the new branch

### Create Terraform Configuration Files

#### 1. Create backend.tf

1. **Create backend.tf**:
   - Create a new `main` folder and create the following files in it.
   - Name it: `backend.tf`
   - Copy and paste the following content:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-actual-bucket-name-here"
       key    = "eks/terraform.tfstate"
       region = var.aws_region
     }
   
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 5.0"
       }
     }
   }
   ```
   - **Important**: Replace `your-actual-bucket-name-here` with your S3 bucket name
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 2. Create providers.tf

1. **Create providers.tf**:
   
   - Create a file named `providers.tf`
   - Copy and paste the following content:
   
   ```hcl
   provider "aws" {
     region = var.aws_region
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 3. Create variables.tf

1. **Create variables.tf**:
   
   - Create a file named `variables.tf`
   - Copy and paste the following content:
   
   ```hcl
   variable "aws_region" {
     description = "AWS region"
     type        = string
     default     = "us-west-1"
   }
   
   variable "cluster_name" {
     description = "Name of the EKS cluster"
     type        = string
     default     = "github-actions-eks"
   }
   
   variable "kubernetes_version" {
     description = "Kubernetes version"
     type        = string
     default     = "1.28"
   }
   
   variable "node_instance_type" {
     description = "EC2 instance type for worker nodes"
     type        = string
     default     = "t3.medium"
   }
   
   variable "node_group_desired_size" {
     description = "Desired number of worker nodes"
     type        = number
     default     = 2
   }
   
   variable "node_group_max_size" {
     description = "Maximum number of worker nodes"
     type        = number
     default     = 4
   }
   
   variable "node_group_min_size" {
     description = "Minimum number of worker nodes"
     type        = number
     default     = 1
   }
   
   variable "project_tags" {
     description = "Tags for the project"
     type        = map(string)
     default = {
       Project     = "github-actions-eks-lab"
       Environment = "dev"
       ManagedBy   = "terraform"
     }
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 3. Create network.tf

1. **Create network.tf**:
   
   - Create a file named `network.tf`
   - Copy and paste the following content:
   
   ```hcl
   # Get available availability zones
   data "aws_availability_zones" "available" {
     state = "available"
   }
   
   # VPC
   resource "aws_vpc" "main" {
     cidr_block           = "10.0.0.0/16"
     enable_dns_hostnames = true
     enable_dns_support   = true
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-vpc"
       "kubernetes.io/cluster/${var.cluster_name}" = "shared"
     })
   }
   
   # Public Subnets
   resource "aws_subnet" "public_1" {
     vpc_id                  = aws_vpc.main.id
     cidr_block              = "10.0.1.0/24"
     availability_zone       = data.aws_availability_zones.available.names[0]
     map_public_ip_on_launch = true
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-public-1"
       "kubernetes.io/cluster/${var.cluster_name}" = "shared"
       "kubernetes.io/role/elb" = "1"
     })
   }
   
   resource "aws_subnet" "public_2" {
     vpc_id                  = aws_vpc.main.id
     cidr_block              = "10.0.2.0/24"
     availability_zone       = data.aws_availability_zones.available.names[1]
     map_public_ip_on_launch = true
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-public-2"
       "kubernetes.io/cluster/${var.cluster_name}" = "shared"
       "kubernetes.io/role/elb" = "1"
     })
   }
   
   # Private Subnets
   resource "aws_subnet" "private_1" {
     vpc_id            = aws_vpc.main.id
     cidr_block        = "10.0.3.0/24"
     availability_zone = data.aws_availability_zones.available.names[0]
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-private-1"
       "kubernetes.io/cluster/${var.cluster_name}" = "owned"
       "kubernetes.io/role/internal-elb" = "1"
     })
   }
   
   resource "aws_subnet" "private_2" {
     vpc_id            = aws_vpc.main.id
     cidr_block        = "10.0.4.0/24"
     availability_zone = data.aws_availability_zones.available.names[1]
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-private-2"
       "kubernetes.io/cluster/${var.cluster_name}" = "owned"
       "kubernetes.io/role/internal-elb" = "1"
     })
   }
   
   # Internet Gateway
   resource "aws_internet_gateway" "main" {
     vpc_id = aws_vpc.main.id
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-igw"
     })
   }
   
   # Elastic IPs for NAT Gateways
   resource "aws_eip" "nat_1" {
     domain = "vpc"
     depends_on = [aws_internet_gateway.main]
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-nat-1"
     })
   }
   
   resource "aws_eip" "nat_2" {
     domain = "vpc"
     depends_on = [aws_internet_gateway.main]
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-nat-2"
     })
   }
   
   # NAT Gateways
   resource "aws_nat_gateway" "nat_1" {
     allocation_id = aws_eip.nat_1.id
     subnet_id     = aws_subnet.public_1.id
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-nat-1"
     })
   }
   
   resource "aws_nat_gateway" "nat_2" {
     allocation_id = aws_eip.nat_2.id
     subnet_id     = aws_subnet.public_2.id
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-nat-2"
     })
   }
   
   # Public Route Table
   resource "aws_route_table" "public" {
     vpc_id = aws_vpc.main.id
   
     route {
       cidr_block = "0.0.0.0/0"
       gateway_id = aws_internet_gateway.main.id
     }
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-public-rt"
     })
   }
   
   # Private Route Tables
   resource "aws_route_table" "private_1" {
     vpc_id = aws_vpc.main.id
   
     route {
       cidr_block     = "0.0.0.0/0"
       nat_gateway_id = aws_nat_gateway.nat_1.id
     }
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-private-rt-1"
     })
   }
   
   resource "aws_route_table" "private_2" {
     vpc_id = aws_vpc.main.id
   
     route {
       cidr_block     = "0.0.0.0/0"
       nat_gateway_id = aws_nat_gateway.nat_2.id
     }
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-private-rt-2"
     })
   }
   
   # Route Table Associations
   resource "aws_route_table_association" "public_1" {
     subnet_id      = aws_subnet.public_1.id
     route_table_id = aws_route_table.public.id
   }
   
   resource "aws_route_table_association" "public_2" {
     subnet_id      = aws_subnet.public_2.id
     route_table_id = aws_route_table.public.id
   }
   
   resource "aws_route_table_association" "private_1" {
     subnet_id      = aws_subnet.private_1.id
     route_table_id = aws_route_table.private_1.id
   }
   
   resource "aws_route_table_association" "private_2" {
     subnet_id      = aws_subnet.private_2.id
     route_table_id = aws_route_table.private_2.id
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 4. Create iam.tf

1. **Create iam.tf**:
   
   - Create a file named `iam.tf`
   - Copy and paste the following content:
   
   ```hcl
   # EKS Cluster Service Role
   resource "aws_iam_role" "eks_cluster" {
     name = "${var.cluster_name}-cluster-role"
   
     assume_role_policy = jsonencode({
       Version = "2012-10-17"
       Statement = [
         {
           Action = "sts:AssumeRole"
           Effect = "Allow"
           Principal = {
             Service = "eks.amazonaws.com"
           }
         }
       ]
     })
   
     tags = var.project_tags
   }
   
   resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
     policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
     role       = aws_iam_role.eks_cluster.name
   }
   
   # EKS Node Group Service Role
   resource "aws_iam_role" "eks_node_group" {
     name = "${var.cluster_name}-node-group-role"
   
     assume_role_policy = jsonencode({
       Version = "2012-10-17"
       Statement = [
         {
           Action = "sts:AssumeRole"
           Effect = "Allow"
           Principal = {
             Service = "ec2.amazonaws.com"
           }
         }
       ]
     })
   
     tags = var.project_tags
   }
   
   resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
     policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
     role       = aws_iam_role.eks_node_group.name
   }
   
   resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
     policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
     role       = aws_iam_role.eks_node_group.name
   }
   
   resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
     policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
     role       = aws_iam_role.eks_node_group.name
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 5. Create eks.tf

1. **Create eks.tf**:
   
   - Create a file named `eks.tf`
   - Copy and paste the following content:
   
   ```hcl
   # EKS Cluster
   resource "aws_eks_cluster" "main" {
     name     = var.cluster_name
     role_arn = aws_iam_role.eks_cluster.arn
     version  = var.kubernetes_version
   
     vpc_config {
       subnet_ids              = [aws_subnet.private_1.id, aws_subnet.private_2.id, aws_subnet.public_1.id, aws_subnet.public_2.id]
       endpoint_private_access = true
       endpoint_public_access  = true
       public_access_cidrs     = ["0.0.0.0/0"]
     }
   
     enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
   
     depends_on = [
       aws_iam_role_policy_attachment.eks_cluster_policy,
       aws_cloudwatch_log_group.eks_cluster,
     ]
   
     tags = merge(var.project_tags, {
       Name = var.cluster_name
     })
   }
   
   # EKS Node Group
   resource "aws_eks_node_group" "main" {
     cluster_name    = aws_eks_cluster.main.name
     node_group_name = "${var.cluster_name}-workers"
     node_role_arn   = aws_iam_role.eks_node_group.arn
     subnet_ids      = [aws_subnet.private_1.id, aws_subnet.private_2.id]
   
     capacity_type  = "ON_DEMAND"
     instance_types = [var.node_instance_type]
   
     scaling_config {
       desired_size = var.node_group_desired_size
       max_size     = var.node_group_max_size
       min_size     = var.node_group_min_size
     }
   
     update_config {
       max_unavailable = 1
     }
   
     depends_on = [
       aws_iam_role_policy_attachment.eks_worker_node_policy,
       aws_iam_role_policy_attachment.eks_cni_policy,
       aws_iam_role_policy_attachment.eks_container_registry_policy,
     ]
   
     tags = merge(var.project_tags, {
       Name = "${var.cluster_name}-workers"
     })
   }
   
   # CloudWatch Log Group for EKS
   resource "aws_cloudwatch_log_group" "eks_cluster" {
     name              = "/aws/eks/${var.cluster_name}/cluster"
     retention_in_days = 7
   
     tags = var.project_tags
   }
   
   # EKS Add-ons
   resource "aws_eks_addon" "vpc_cni" {
     cluster_name = aws_eks_cluster.main.name
     addon_name   = "vpc-cni"
     depends_on   = [aws_eks_node_group.main]
   }
   
   resource "aws_eks_addon" "coredns" {
     cluster_name = aws_eks_cluster.main.name
     addon_name   = "coredns"
     depends_on   = [aws_eks_node_group.main]
   }
   
   resource "aws_eks_addon" "kube_proxy" {
     cluster_name = aws_eks_cluster.main.name
     addon_name   = "kube-proxy"
     depends_on   = [aws_eks_node_group.main]
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 6. Create outputs.tf

1. **Create outputs.tf**:
   
   - Create a file named `outputs.tf`
   - Copy and paste the following content:
   
   ```hcl
   # EKS Cluster Outputs
   output "cluster_id" {
     description = "EKS cluster ID"
     value       = aws_eks_cluster.main.id
   }
   
   output "cluster_arn" {
     description = "EKS cluster ARN"
     value       = aws_eks_cluster.main.arn
   }
   
   output "cluster_endpoint" {
     description = "EKS cluster endpoint"
     value       = aws_eks_cluster.main.endpoint
   }
   
   output "cluster_security_group_id" {
     description = "Security group ID attached to the EKS cluster"
     value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
   }
   
   output "cluster_version" {
     description = "EKS cluster version"
     value       = aws_eks_cluster.main.version
   }
   
   output "cluster_platform_version" {
     description = "EKS cluster platform version"
     value       = aws_eks_cluster.main.platform_version
   }
   
   output "cluster_status" {
     description = "EKS cluster status"
     value       = aws_eks_cluster.main.status
   }
   
   output "node_group_arn" {
     description = "EKS node group ARN"
     value       = aws_eks_node_group.main.arn
   }
   
   output "node_group_status" {
     description = "EKS node group status"
     value       = aws_eks_node_group.main.status
   }
   
   output "vpc_id" {
     description = "VPC ID"
     value       = aws_vpc.main.id
   }
   
   output "vpc_cidr_block" {
     description = "VPC CIDR block"
     value       = aws_vpc.main.cidr_block
   }
   
   output "private_subnet_ids" {
     description = "Private subnet IDs"
     value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
   }
   
   output "public_subnet_ids" {
     description = "Public subnet IDs"
     value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
   }
   
   output "kubeconfig_command" {
     description = "Command to configure kubectl"
     value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

### Create GitHub Actions Workflows

#### 1. Create terraform-plan-apply.yml

1. **Create terraform-plan-apply.yml**:
   - Create a folder in the repository root named `.github/workflows`
   - Create a file named `terraform-plan-apply.yml`
   - Copy and paste the following content:
   ```yaml
   name: 'Terraform EKS Pipeline'
   
   on:
     push:
       branches: [ "feature/**" ]
     workflow_dispatch:
   
   permissions:
     contents: read
     pull-requests: write
   
   env:
     TERRAFORM_DIR: './main'
     AWS_REGION: 'us-west-1'
   
   jobs:
     terraform-plan:
       name: 'Terraform Plan'
       runs-on: ubuntu-latest
       outputs:
         tfplanExitCode: ${{ steps.tf-plan.outputs.exitcode }}
   
       steps:
       - uses: actions/checkout@v4
   
       - name: Configure AWS Credentials
         uses: aws-actions/configure-aws-credentials@v4
         with:
           aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
           aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
           aws-region: '${{ env.AWS_REGION }}'
   
       - name: Setup Terraform
         uses: hashicorp/setup-terraform@v3
         with:
           terraform_version: "1.8.0"
   
       - name: Terraform Init
         run: |
           terraform init
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Terraform Plan
         id: tf-plan
         run: |
           exit_code=0
           terraform plan -detailed-exitcode -no-color -out=tfplan || exit_code=$?
           echo "exitcode=${exit_code}" >> $GITHUB_OUTPUT
           if [ $exit_code -eq 1 ]; then
             echo "Terraform Plan Failed!"
             exit 1
           fi
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Upload Terraform Plan
         uses: actions/upload-artifact@v4
         with:
           name: tfplan
           path: ${{ env.TERRAFORM_DIR }}/tfplan
           retention-days: 1
   
     approval:
       name: 'Approve Terraform Plan'
       needs: terraform-plan
       runs-on: ubuntu-latest
       environment: gh-actions-lab
       steps:
         - run: echo "Waiting for approval..."
   
     terraform-apply:
       name: 'Terraform Apply'
       needs: [terraform-plan, approval]
       runs-on: ubuntu-latest
       
       steps:
       - uses: actions/checkout@v4
   
       - name: Configure AWS Credentials
         uses: aws-actions/configure-aws-credentials@v4
         with:
           aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
           aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
           aws-region: '${{ env.AWS_REGION }}'
   
       - name: Setup Terraform
         uses: hashicorp/setup-terraform@v3
         with:
           terraform_version: "1.8.0"
   
       - name: Terraform Init
         run: terraform init
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Download Terraform Plan
         uses: actions/download-artifact@v4
         with:
           name: tfplan
           path: ${{ env.TERRAFORM_DIR }}
   
       - name: Terraform Apply
         run: terraform apply -auto-approve tfplan
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Update kubeconfig
         run: |
           aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name github-actions-eks
           kubectl get nodes
         working-directory: ${{ env.TERRAFORM_DIR }}
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

#### 2. Create terraform-destroy.yml

1. **Create terraform-destroy.yml**:
   - In the `.github/workflows` folder
   - Create a file named `terraform-destroy.yml`
   - Copy and paste the following content:
   ```yaml
   name: 'Terraform EKS Destroy'
   
   on:
     workflow_dispatch:
   
   permissions:
     contents: read
     pull-requests: write
   
   env:
     TERRAFORM_DIR: './main'
     AWS_REGION: 'us-west-1'
   
   jobs:
     terraform-destroy-plan:
       name: 'Terraform Destroy Plan'
       runs-on: ubuntu-latest
       outputs:
         tfplanExitCode: ${{ steps.tf-plan.outputs.exitcode }}
   
       steps:
       - uses: actions/checkout@v4
   
       - name: Configure AWS Credentials
         uses: aws-actions/configure-aws-credentials@v4
         with:
           aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
           aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
           aws-region: '${{ env.AWS_REGION }}'
       - name: Setup Terraform
         uses: hashicorp/setup-terraform@v3
         with:
           terraform_version: "1.8.0"
   
       - name: Terraform Init
         run: terraform init
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Terraform Plan Destroy
         id: tf-plan
         run: |
           exit_code=0
           terraform plan -destroy -detailed-exitcode -no-color -out=tfplan || exit_code=$?
           echo "exitcode=${exit_code}" >> $GITHUB_OUTPUT
           if [ $exit_code -eq 1 ]; then
             echo "Terraform Plan Failed!"
             exit 1
           fi
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Upload Terraform Plan
         uses: actions/upload-artifact@v4
         with:
           name: tfplan
           path: ${{ env.TERRAFORM_DIR }}/tfplan
           retention-days: 1
   
     approval:
       name: 'Approve Terraform Destroy'
       needs: terraform-destroy-plan
       runs-on: ubuntu-latest
       environment: gh-actions-lab
       steps:
         - run: echo "Waiting for approval to destroy..."
   
     terraform-destroy:
       name: 'Terraform Destroy'
       needs: [terraform-destroy-plan, approval]
       runs-on: ubuntu-latest
       
       steps:
       - uses: actions/checkout@v4
   
       - name: Configure AWS Credentials
         uses: aws-actions/configure-aws-credentials@v4
         with:
           aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
           aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
           aws-region: '${{ env.AWS_REGION }}'
   
       - name: Setup Terraform
         uses: hashicorp/setup-terraform@v3
         with:
           terraform_version: "1.8.0"
   
       - name: Terraform Init
         run: terraform init
         working-directory: ${{ env.TERRAFORM_DIR }}
   
       - name: Download Terraform Plan
         uses: actions/download-artifact@v4
         with:
           name: tfplan
           path: ${{ env.TERRAFORM_DIR }}
   
       - name: Terraform Destroy
         run: terraform apply -auto-approve tfplan
         working-directory: ${{ env.TERRAFORM_DIR }}
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

### Commit Initial Configuration using VS Code

1. **Stage and Commit using VS Code GUI**:
   - Click on the **Source Control** icon in the left sidebar (looks like a branch)
   - You'll see all your changes listed under "Changes"
   - Click the "+" button next to "Changes" to stage all files
   - In the message box at the top, type: `Initial EKS lab configuration with Terraform and GitHub Actions`
   - Click the **Commit** button (checkmark icon)

2. **Push to GitHub using VS Code GUI**:
   - After committing, you'll see a "Sync Changes" button or "Publish Branch" button
   - Click it to push your new branch to GitHub
   - If prompted, authenticate with GitHub

---

## Part 5: Pipeline Configuration and Testing

### Review Terraform Configuration

Before deploying, let's understand what we're building:

1. **VPC and Networking**: A production-ready VPC with public and private subnets across multiple AZs
2. **EKS Cluster**: A managed Kubernetes cluster with proper IAM roles and security groups
3. **Node Groups**: Managed worker nodes with auto-scaling capabilities
4. **Security**: Proper security groups and IAM roles following AWS best practices

### Trigger the Pipeline

1. Go to your repository's Actions tab
2. You should see the "Terraform EKS Pipeline" workflow
3. Since we pushed to a feature branch, the workflow should trigger automatically
4. Monitor the pipeline execution

### Review the Plan

The pipeline will:
1. **Terraform Plan**: Analyze what resources will be created
2. **Approval Gate**: Wait for manual approval
3. **Terraform Apply**: Create the infrastructure

When the plan completes, you should see approximately **25-30 resources** to be created, including:
- VPC, subnets, and networking components
- EKS cluster and node groups
- IAM roles and policies
- Security groups
- CloudWatch log groups

### Approve the Deployment

1. Click on the "Approve Terraform Plan" job
2. Review the detailed plan output
3. Verify the resource count matches expectations
4. Click "Review deployments"
5. Click "Approve and deploy"

> **Important**: Only approve if the plan looks correct. EKS clusters incur costs!

---

## Part 6: Verify EKS Deployment

### Check Cluster Status

1. Wait for the terraform apply job to complete (20-25 minutes)
2. Go to AWS Console → EKS → Clusters
3. Verify the `github-actions-eks` cluster is active
4. Check the node group status

### Configure kubectl Access

The GitHub Actions workflow automatically configures kubectl, but if you experience any issues, you can also do it locally:

1. **Open VS Code Terminal in Bash mode**:
   - Press `Ctrl+` (backtick) or go to **Terminal → New Terminal**
   - If not in Bash mode, click the dropdown arrow next to the terminal name and select "Git Bash"

2. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-west-1 --name github-actions-eks
   kubectl get nodes
   ```

You should see 2 worker nodes in the `Ready` state.

### Test Kubernetes Access

In the VS Code terminal (Bash mode), run:

```bash
# Check cluster info
kubectl cluster-info

# Check all namespaces
kubectl get namespaces

# Check system pods
kubectl get pods -n kube-system
```

---

## Part 7: Modify and Update the Cluster

### Update Node Group Configuration

Let's demonstrate infrastructure updates by modifying the node group:

1. **Edit variables.tf using VS Code**:
   
   - Open `variables.tf` in the editor
   - Update the node group configuration:
   
   ```hcl
   variable "node_group_desired_size" {
     description = "Desired number of worker nodes"
     type        = number
     default     = 3  # Changed from 2 to 3
   }
   
   variable "node_instance_type" {
     description = "EC2 instance type for worker nodes"
     type        = string
     default     = "t3.large"  # Changed from t3.medium
   }
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

### Deploy the Changes

1. **Stage and Commit using VS Code GUI**:
   - Go to the **Source Control** panel (left sidebar)
   - Stage all changes by clicking the "+" next to "Changes"
   - Enter commit message: `Scale node group to 3 nodes with t3.large instances`
   - Click the **Commit** button
   - Click **Sync Changes** to push to GitHub

### Monitor the Update

1. Go to Actions tab and watch the new workflow
2. Review the plan - you should see:
   - 1 resource to change (node group)
   - New desired capacity: 3
   - New instance type: t3.large
3. Approve the changes
4. Wait for completion

### Verify the Update

In the VS Code terminal (Bash mode), run:

```bash
kubectl get nodes
# You should now see 3 nodes with t3.large instance types
```

---

## Part 8: Deploy a Sample Application

### Create a Sample App

Let's deploy a simple application to test our EKS cluster:

1. **Create sample-app.yaml using VS Code**:
   - Right-click in the root directory in Explorer
   - Select "New File"
   - Name it: `sample-app.yaml`
   - Copy and paste the following content:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: nginx-deployment
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: nginx
     template:
       metadata:
         labels:
           app: nginx
       spec:
         containers:
         - name: nginx
           image: nginx:latest
           ports:
           - containerPort: 80
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-service
   spec:
     selector:
       app: nginx
     ports:
     - port: 80
       targetPort: 80
     type: LoadBalancer
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

2. **Deploy the application using VS Code terminal**:
   - Open terminal in Bash mode (`Ctrl+` backtick)
   - Run:
   ```bash
   kubectl apply -f sample-app.yaml
   ```

3. **Get the LoadBalancer URL**:
   ```bash
   kubectl get service nginx-service
   ```

4. **Test the application** by accessing the external IP in your browser

---

## Part 9: Cleanup Workflow

### Configure Automatic Cleanup

For cost management, let's set up an automated cleanup workflow:

1. **Edit terraform-destroy.yml using VS Code**:
   - In Explorer, navigate to `.github/workflows/terraform-destroy.yml`
   - Click on the file to open it in the editor
   - Add a scheduled trigger:
   ```yaml
   on:
     workflow_dispatch:
     schedule:
       - cron: '0 22 * * *'  # Run at 10 PM UTC daily
   ```
   - Save the file (`Ctrl+S` or `Cmd+S`)

### Manual Cleanup

To immediately clean up resources:

1. Go to Actions tab
2. Select "Terraform EKS Destroy" workflow
3. Click "Run workflow"
4. Review the destroy plan (should show ~25-30 resources to destroy)
5. Approve the destruction

### Verify Cleanup

1. Check AWS Console - EKS cluster should be deleted
2. Verify all associated resources are cleaned up

---

## Part 10: Advanced Configurations

### Environment-Specific Deployments

For production use, consider these enhancements:

1. **Multiple Environments**: Create separate workspaces for dev/staging/prod
2. **Environment Variables**: Use GitHub environments for different AWS accounts
3. **Approval Workflows**: Implement different approval requirements per environment

### Security Enhancements

1. **IRSA (IAM Roles for Service Accounts)**: Replace long-term credentials
2. **VPC Endpoints**: Add VPC endpoints for AWS services
3. **Network Policies**: Implement Kubernetes network policies
4. **Pod Security Standards**: Enable pod security standards

### Monitoring and Observability

1. **CloudWatch Container Insights**: Enable for cluster monitoring
2. **Prometheus and Grafana**: Deploy for metrics collection
3. **Fluent Bit**: Configure for log aggregation
4. **AWS X-Ray**: Implement for distributed tracing

---

## Completion

**Congratulations!** You've successfully completed the GitHub Actions EKS CI/CD Pipeline lab!

### What You've Accomplished

**Infrastructure as Code**: Deployed a production-ready EKS cluster using Terraform
**CI/CD Pipeline**: Created automated deployment workflows with GitHub Actions
**Security**: Implemented approval workflows and secret management
**Scalability**: Demonstrated cluster scaling and updates
**Real-world Skills**: Learned industry-standard DevOps practices

### Key Takeaways

1. **Automation**: Infrastructure should be versioned and automated
2. **Security**: Always use approval workflows for production deployments
3. **Cost Management**: Implement cleanup workflows to prevent surprise bills
4. **Monitoring**: Real-world deployments need observability and monitoring
5. **Scalability**: Cloud-native infrastructure should be designed for growth

## Troubleshooting Guide

### Common Issues and Solutions

#### Pipeline Failures

**Issue**: "Error: Backend configuration changed"
**Solution**: Run `terraform init -reconfigure` or delete the `.terraform` directory

**Issue**: "403 Forbidden" errors
**Solution**: Verify AWS credentials have the necessary EKS permissions

#### EKS Cluster Issues

**Issue**: Nodes not joining the cluster
**Solution**: Check VPC configuration and security groups

**Issue**: kubectl access denied
**Solution**: Verify your AWS credentials and run `aws eks update-kubeconfig`

#### Cost Management

**Issue**: Unexpected AWS charges
**Solution**: Always run the destroy workflow when done with testing

**Issue**: EKS cluster won't delete
**Solution**: Ensure all LoadBalancer services are deleted first

---

