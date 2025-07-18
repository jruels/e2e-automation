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

### Fork the Repository

- Go to your course repository page
- Click the "Fork" button in the top right
- Select your personal account as the destination

### Create a New Repository (Alternative)

If you prefer to create your own repository:

1. Create a new repository named `github-actions-eks-lab`
2. Initialize it with a README
3. Clone the repository locally

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
5. Region: `us-west-2`
6. Enable versioning for state file history
7. Enable default encryption
8. Block all public access
9. Click "Create bucket"

> **Important**: Remember your bucket name - you'll need it in the next step.

---

## Part 4: Repository Configuration

### Clone and Create Feature Branch

1. Clone your repository:
   ```bash
   git clone https://github.com/YOUR-USERNAME/REPO-NAME.git
   cd REPO-NAME
   ```

2. Create the lab directory structure:
   ```bash
   mkdir -p labs/gh-actions-eks/main
   mkdir -p .github/workflows
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/eks-deployment
   ```

### Copy Lab Files

Copy the Terraform configuration files and GitHub Actions workflows to your repository:

1. Copy the `main/` directory contents to `labs/gh-actions-eks/main/`
2. Copy the `.github/workflows/` directory contents to `.github/workflows/`

### Update Backend Configuration

1. Edit `labs/gh-actions-eks/main/backend.tf`
2. Update the bucket name to match your created bucket:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-actual-bucket-name-here"
       key    = "eks/terraform.tfstate"
       region = "us-west-2"
     }
   }
   ```

### Commit Initial Configuration

```bash
git add .
git commit -m "Initial EKS lab configuration with Terraform and GitHub Actions"
git push -u origin feature/eks-deployment
```

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

1. Wait for the terraform apply job to complete (10-15 minutes)
2. Go to AWS Console → EKS → Clusters
3. Verify the `github-actions-eks` cluster is active
4. Check the node group status

### Configure kubectl Access

The GitHub Actions workflow automatically configures kubectl, but you can also do it locally:

```bash
aws eks update-kubeconfig --region us-west-2 --name github-actions-eks
kubectl get nodes
```

You should see 2 worker nodes in the `Ready` state.

### Test Kubernetes Access

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

1. Edit `labs/gh-actions-eks/main/variables.tf`
2. Update the node group configuration:
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

### Deploy the Changes

```bash
git add .
git commit -m "Scale node group to 3 nodes with t3.large instances"
git push
```

### Monitor the Update

1. Go to Actions tab and watch the new workflow
2. Review the plan - you should see:
   - 1 resource to change (node group)
   - New desired capacity: 3
   - New instance type: t3.large
3. Approve the changes
4. Wait for completion

### Verify the Update

```bash
kubectl get nodes
# You should now see 3 nodes with t3.large instance types
```

---

## Part 8: Deploy a Sample Application

### Create a Sample App

Let's deploy a simple application to test our EKS cluster:

1. Create `sample-app.yaml`:
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

2. Deploy the application:
   ```bash
   kubectl apply -f sample-app.yaml
   ```

3. Get the LoadBalancer URL:
   ```bash
   kubectl get service nginx-service
   ```

4. Test the application by accessing the external IP in your browser

---

## Part 9: Cleanup Workflow

### Configure Automatic Cleanup

For cost management, let's set up an automated cleanup workflow:

1. Edit `.github/workflows/terraform-destroy.yml`
2. Add a scheduled trigger:
   ```yaml
   on:
     workflow_dispatch:
     schedule:
       - cron: '0 22 * * *'  # Run at 10 PM UTC daily
   ```

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
3. Check AWS billing to ensure no ongoing charges

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

🎉 **Congratulations!** You've successfully completed the GitHub Actions EKS CI/CD Pipeline lab!

### What You've Accomplished

✅ **Infrastructure as Code**: Deployed a production-ready EKS cluster using Terraform
✅ **CI/CD Pipeline**: Created automated deployment workflows with GitHub Actions
✅ **Security**: Implemented approval workflows and secret management
✅ **Scalability**: Demonstrated cluster scaling and updates
✅ **Real-world Skills**: Learned industry-standard DevOps practices

### Key Takeaways

1. **Automation**: Infrastructure should be versioned and automated
2. **Security**: Always use approval workflows for production deployments
3. **Cost Management**: Implement cleanup workflows to prevent surprise bills
4. **Monitoring**: Real-world deployments need observability and monitoring
5. **Scalability**: Cloud-native infrastructure should be designed for growth

### Next Steps

- Explore Kubernetes operators and custom resources
- Implement GitOps workflows with ArgoCD or Flux
- Add automated testing and security scanning to your pipeline
- Learn about service mesh technologies like Istio
- Explore serverless containers with AWS Fargate

---

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

## Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

*This lab provides hands-on experience with enterprise-grade DevOps practices. The skills learned here are directly applicable to real-world cloud infrastructure management.*
