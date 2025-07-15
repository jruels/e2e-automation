# Terraform - import existing resources

## Overview
In this lab, you will create AWS resources using the console and import them into Terraform management. 

## Create instances in AWS Console
Create three EC2 instances in the AWS Console. 

1. Using the search bar at the top of the page, search for `EC2` and click the first result, as shown in the screenshot. 

![ec2 search](images/ec2_search.png)
2. In the EC2 dashboard, click Instances, and then `Launch Instances`. 
3. Click `Add additional tags` and set Key to `role` and Value `terraform`. 
4. In the list, select the top "Amazon Linux" AMI. 

![aws-ami](images/aws_ami.png)
4. Select the `t2.micro` instance type and set `Number of instances` to `3`
5. Set `Key pair` to `Proceed without a key pair`
6. Leave defaults for all other options.
7. Click `Launch instance` 

## Create Terraform configuration 
While waiting for the instances to launch, create a new working directory and configuration file. 

1. In **Visual Studio Code**, open the working directory created in the previous lab (`YYYYMMDD/terraform`).

2. Right-click in the **Explorer** pane and select **New Folder**.

3. Name the folder `tf-lab4`.

4. Right-click `tf-lab4` and select **New File**.

5. Name the file `main.tf` and add a resource with the following attributes:

   - type: `aws_instance`

   - name: `tf-example-import`

   - ami: AMI from instances created above

   - instance_type: The type specified when creating the instance.

   - count: `3`

   - tags: `Name: TF-example-import`, `role: terraform`


Remember, this resource block is for three instances. You will need to add the `count.index` to the `Name` tag. If you get stuck, ask the instructor for assistance.

## Import the configuration 
Now that you've created the instances and the Terraform configuration, use the `terraform import` command to import the existing instances. 

If you get stuck, check the help page `terraform import --help` or the [terraform documentation](https://www.terraform.io/docs/cli/import/index.html)



