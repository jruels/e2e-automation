# Terraform Workspace Solution

This directory contains the complete working solution for the Terraform workspace lab.

## Files

- `main.tf` - Main Terraform configuration with workspace-aware S3 bucket naming
- `variables.tf` - Variable definitions for region and prefix
- `outputs.tf` - Output definitions including workspace information
- `terraform.tfvars` - Default variable values
- `dev.tfvars` - Development environment specific variables
- `prod.tfvars` - Production environment specific variables  
- `assets/index.html` - Sample HTML file to be uploaded to S3
- `commands.txt` - All commands needed to run the solution

## Key Features

1. **Workspace Integration**: Uses `terraform.workspace` variable to create unique bucket names per environment
2. **Resource References**: All resources properly reference the S3 bucket resource instead of hardcoded names
3. **Proper Dependencies**: Includes all necessary S3 bucket configurations for website hosting
4. **Environment-specific Variables**: Supports different configurations per workspace via .tfvars files

## Usage

1. Navigate to this directory
2. Run `terraform init`
3. Create and switch to workspaces using `terraform workspace new <name>`
4. Deploy with `terraform apply`
5. Use `-var-file` for environment-specific configurations

See `commands.txt` for detailed command sequences.

## Expected Outcomes

- Dev workspace creates bucket: `dev-webapp-<random-pet-name>`
- Prod workspace creates bucket: `prod-webapp-<random-pet-name>`
- Each workspace maintains separate state files
- Website endpoints are accessible and show "Hello from Terraform Workspace!"
