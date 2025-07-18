# GitOps with GitHub Actions and Argo CD

## Overview

This hands-on lab teaches you how to implement a GitOps workflow using open-source tools and public cloud infrastructure. You'll learn how to:

* Build and version containerized applications with GitHub Actions
* Store and update Kubernetes manifests using Git as a source of truth
* Automate application deployments with Argo CD

By the end of this lab, you'll have a fully functional GitOps pipeline using:

* **Docker Hub** for container image storage
* **GitHub** for application and environment code
* **GitHub Actions** for CI/CD automation
* **Argo CD** for continuous delivery to your existing EKS Kubernetes cluster

---

## Part 1: Docker Hub and GitHub Setup

### Overview

In this section, you'll configure Docker Hub (to store container images) and GitHub (to host source code and automation workflows). These services will form the foundation of your GitOps pipeline.

### Step 1: Docker Hub Setup

Docker Hub is a cloud registry for storing and sharing container images. You'll use it to push and pull your application container.

1. Go to [https://hub.docker.com](https://hub.docker.com)
2. Log in or create a new Docker Hub account
3. Click your profile icon → **Account Settings**
4. Navigate to **Settings** -> **Personal Access Token**
5. Create a token with:

   * **Name**: `github-actions`
   * **Permissions**: `Read/Write`
6. Click **Generate Token** and save it somewhere secure

> You'll use this token as `REGISTRY_TOKEN` later in GitHub secrets.

### Step 2: Create Docker Repository

Create a public Docker Hub repository named `example-application`:

1. From your Docker Hub dashboard, click **Repositories**
2. Click **Create Repository**
3. Enter:

   * **Repository Name**: `example-application`
   * **Visibility**: Public
4. Click **Create**

This is where GitHub Actions will publish your built container images.

### Step 3: GitHub Setup

GitHub will store your application code, Kubernetes manifests, and automation workflows.

1. Go to [https://github.com](https://github.com)
2. Log in or create a new GitHub account

### Step 4: Create Repositories

You'll need two repositories:

* `example-application` – source code and build workflows
* `example-environment` – Kubernetes manifests and Argo CD config

To create each repository:

1. Go to [https://github.com/new](https://github.com/new)
2. Set repository name accordingly
3. Choose **Public**
4. Choose to create a README, and leave the rest default.
5. Click **Create repository**

### Step 5: Create GitHub Personal Access Token

A GitHub PAT is required to trigger workflows across repositories and commit changes to the manifest repo.

1. Go to [https://github.com/settings/tokens](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Configure token:

   * **Name**: `GitOps GitHub Actions`
   * **Scopes**:
     * `repo`
     * `workflow`
4. Click **Generate Token**
5. Copy and save the token securely

You'll add this as `PERSONAL_ACCESS_TOKEN` in your GitHub secrets in the next section.

## Part 2: Configure GitHub Secrets and Variables

### Overview

To securely authenticate GitHub Actions workflows with Docker Hub and across repositories, you'll need to configure secrets in both repositories. Secrets allow your pipeline to perform automated actions like pushing container images and creating pull requests.

### Step 1: Add Secrets to `example-application`

In your `example-application` repository:

1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret** and add the following:

| Name                    | Description                             |
| ----------------------- | --------------------------------------- |
| `REGISTRY_USER`         | Your Docker Hub username                |
| `REGISTRY_TOKEN`        | Docker Hub access token                 |
| `PERSONAL_ACCESS_TOKEN` | GitHub PAT for triggering env workflows |

These secrets will be accessed during the CI pipeline to log in to Docker Hub and trigger a deployment workflow in the environment repository.

### Step 2: Add Secrets and Variables to `example-environment`

In your `example-environment` repository:

1. Go to **Settings → Secrets and variables → Actions**
2. Add a secret:
   - `PERSONAL_ACCESS_TOKEN`: same GitHub PAT as above
3. Add a repository-level variable:
   - `DOCKER_HUB_IMAGE`: set to `docker.io/YOUR_USERNAME/example-application`

> This variable is used in workflows to avoid hardcoding image references. Variables are great for reusable pipelines.

### Summary

Secrets are an essential security feature in GitHub Actions. They allow secure access to external systems (like Docker Hub or another GitHub repo) without exposing credentials in source code.

## Part 3: Write and Package Your Application

### Overview

In this step, you will write a simple Flask-based Python web application and package it using Docker. You will use Visual Studio Code to create and edit files locally.

### Step 1: Clone Your Repository

1. In Visual Studio Code, open the terminal
2. Clone your `example-application` repository:

```bash
git clone https://github.com/YOUR_USERNAME/example-application.git
cd example-application
```

### Step 2: Create `main.py`

1. In Visual Studio Code, create a new file called `main.py`
2. Add the following code:

```python
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return 'Hello Argo CD v1.0!'

app.run(host='0.0.0.0', port=8080)
```

This Flask app will respond to HTTP requests at the root path.

### Step 3: Create a `Dockerfile`

1. In the same directory, create a new file called `Dockerfile`
2. Add the following contents:

```dockerfile
FROM python:3.8-alpine
WORKDIR /py-app
COPY . .
RUN pip3 install flask
EXPOSE 8080
CMD ["python3", "main.py"]
```

This Dockerfile tells Docker how to package your Python application.

### Step 4: Commit and Push Your Changes

1. In the terminal, run:

```bash
git add .
git commit -m "Initial Flask app with Dockerfile"
git push origin main
```

### Summary

You now have a simple containerized application written and committed using Visual Studio Code. In the next part, you'll create a GitHub Actions workflow to automatically build and push your app to Docker Hub.

## Part 4: Build and Deploy Using GitHub Actions

### Overview

In this section, you'll create a GitHub Actions workflow in your `example-application` repository. The workflow will automatically build your application into a Docker image and prepare to trigger an update in the `example-environment` repository when a new Git tag is pushed.

### Step 1: Create the GitHub Actions Workflow

1. In Visual Studio Code, create the following directory structure: `.github/workflows`
2. Inside that folder, create a new file named `release.yaml`
3. Paste the following content: (Replace **YOUR_USERNAME** with your GitHub username).

```yaml
name: Release and Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Set TAG_NAME
        run: echo "TAG_NAME=${GITHUB_REF#refs/tags/}" >> $GITHUB_ENV

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.REGISTRY_USER }}
          password: ${{ secrets.REGISTRY_TOKEN }}

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: docker.io/${{ secrets.REGISTRY_USER }}/example-application:${{ env.TAG_NAME }}

  trigger-deployment-update:
    runs-on: ubuntu-latest
    needs: build-and-push
    steps:
      - name: Set TAG_NAME again
        run: echo "TAG_NAME=${GITHUB_REF#refs/tags/}" >> $GITHUB_ENV

      - name: Trigger workflow in env repo
        uses: benc-uk/workflow-dispatch@v1
        with:
          workflow: update-deployment.yaml
          repo: YOUR_USERNAME/example-environment
          token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          ref: main
          inputs: |
            {
              "tag_name": "${{ env.TAG_NAME }}",
              "image": "docker.io/${{ secrets.REGISTRY_USER }}/example-application"
            }
```

### Step 2: Commit and Push the Workflow

1. In the terminal, run:

```bash
git add .
git commit -m "Add release workflow"
git push origin main
```

> You are now ready to move on to Part 5 to configure the `example-environment` repo.

### Summary

You have created a GitHub Actions workflow that listens for version tags and builds a container image. In the next section, you'll define the Kubernetes deployment and its update workflow. Once both workflows are in place, you'll trigger the pipeline with a tag.

## Part 5: Define Kubernetes Deployment and Update Workflow

### Overview

In this section, you'll configure the `example-environment` repository to store your Kubernetes manifests and automate updates to your deployment YAML whenever a new image is published. This completes the second half of your GitOps pipeline and prepares you to trigger deployments — once Argo CD is set up in the next section.

### Step 1: Clone and Set Up `example-environment`

1. In Visual Studio Code, open a new terminal or navigate to a different directory
2. Clone your `example-environment` repository:

```bash
git clone https://github.com/YOUR_USERNAME/example-environment.git
cd example-environment
```

### Step 2: Create the Kubernetes Deployment Manifest

> Before continuing, make sure to replace all instances of `YOUR_USERNAME` in the file below with your actual Docker Hub username.

1. Create the following directory structure: `applications/example-application`
2. Inside `applications/example-application`, create a new file: `deployment.yaml`
3. Add the following YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-application
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-application
  template:
    metadata:
      labels:
        app: example-application
    spec:
      containers:
      - name: example-application
        image: docker.io/YOUR_USERNAME/example-application:v1.0.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: example-application
spec:
  type: LoadBalancer
  selector:
    app: example-application
  ports:
  - port: 8080
```

This manifest defines a simple deployment and a LoadBalancer service.

### Step 3: Create the GitHub Actions Workflow

1. Create the directory structure: `.github/workflows`
2. Inside the folder, create a file: `update-deployment.yaml`
3. Add the following content:

```yaml
name: Update Deployment

on:
  workflow_dispatch:
    inputs:
      tag_name:
        required: true
      image:
        required: true

jobs:
  update-manifest:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Update Image Tag
        run: |
          sed -i "s|image: .*|image: ${{ github.event.inputs.image }}:${{ github.event.inputs.tag_name }}|" applications/example-application/deployment.yaml

      - name: Commit and PR
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          commit-message: "Update to ${{ github.event.inputs.tag_name }}"
          branch: update-${{ github.event.inputs.tag_name }}
          title: "Deploy version ${{ github.event.inputs.tag_name }}"
          body: "This PR updates the image to ${{ github.event.inputs.tag_name }}"
```

This workflow allows the `example-application` repo to trigger a manifest update via GitHub Actions and open a pull request automatically.

### Step 4: Commit and Push Your Changes

1. In the terminal, run:

```bash
git add .
git commit -m "Add Kubernetes manifest and update workflow"
git push origin main
```

### What's Next

Before pushing a Git tag to trigger the full release pipeline, we need to install and configure Argo CD in the next section. Once Argo CD is installed and synced to your `example-environment` repo, it will automatically detect and apply manifest updates triggered by your GitHub workflows.

## Part 6: Install and Configure Argo CD

### Overview

In this section, you will install Argo CD into your EKS cluster and configure it through the web UI to monitor your `example-environment` GitHub repository. Argo CD will automatically sync changes from GitHub to your Kubernetes cluster.

### Step 1: Install Argo CD on the Cluster

From your Visual Studio Code terminal, run:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

This command installs Argo CD into the `argocd` namespace using the official manifests.

### Step 2: Expose the Argo CD API Server

Patch the Argo CD server service to use a LoadBalancer so you can access it externally:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Retrieve the external hostname or IP:

```bash
kubectl get svc argocd-server -n argocd
```

It may take 2–3 minutes for the external IP or DNS name to appear.

### Step 3: Get the Argo CD Admin Password

Retrieve the password for the default `admin` user:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Use this to log into the web UI.

### Step 4: Access and Log Into Argo CD

1. Open a browser and go to: `https://<ARGOCD-EXTERNAL-DNS>`
2. Accept the self-signed certificate warning if prompted
3. Log in using:
   - **Username**: `admin`
   - **Password**: (use the value retrieved in the previous step)

### Step 5: Connect the EKS Cluster (Using the Web UI)

1. In the Argo CD UI, go to **Settings → Clusters**
2. Click **Connect Cluster**
3. Choose **In-Cluster** if you're deploying to the same cluster where Argo CD is installed
4. Follow the instructions provided to complete the registration (if prompted, allow Argo CD to manage permissions)

### Step 6: Register the Application Repo

1. Go to **Settings → Repositories**
2. Click **Connect Repo using HTTPS**
3. Set the following:
   - **Type**: Git
   - **Project**: `default`
   - **Name**: `example-environment`
   - **URL**: `https://github.com/YOUR_USERNAME/example-environment`
   - Leave the rest blank (public repo)
4. Click **Connect**

### Step 7: Create an Argo CD Application via UI

1. In the left menu, click **Applications → NEW APP**
2. Fill out the form:
   - **Application Name**: `example-application`
   - **Project**: `default`
   - **Sync Policy**: Enable **Auto-Sync** and check both **Prune Resources** and **Self-Heal**
   - **Repository URL**: Select your GitHub repo from the dropdown
   - **Revision**: `main`
   - **Path**: `applications/example-application`
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: `default`
3. Click **Create**

Argo CD will now begin syncing your `example-environment` repo automatically.

### Step 8: Verify Argo CD Sync

- In the Argo CD dashboard, locate your `example-application` app
- Confirm that it shows **Synced** and **Healthy**
- Click into the app to view Kubernetes resources such as Deployment and Service

Auto-sync ensures Argo CD continuously watches the Git repo and applies changes as they are committed.

### Summary

Argo CD is now installed, configured, and synced with your GitHub repo. With auto-sync enabled, your cluster will always reflect the latest state of your manifests. You're now ready to move to Part 7 and trigger the full GitOps workflow by pushing a release tag.

## Part 7: Push a Tag and Trigger the GitOps Pipeline

### Overview

In this final part of the lab, you'll push a Git tag to your `example-application` repository. This tag will trigger your GitHub Actions workflow to:

- Build and push a Docker image
- Trigger a PR to update your Kubernetes deployment YAML
- Let Argo CD automatically apply the update to your EKS cluster

### Step 1: Navigate to the `example-application` Repository

In Visual Studio Code, make sure you're in the `example-application` directory:

```bash
cd example-application
```

### Step 2: Tag and Push the Release

From the terminal:

```bash
git tag v1.0.0
git push origin v1.0.0
```

> This must be pushed to the `main` branch for the workflow to trigger.

### Step 3: Watch the GitHub Actions Workflow

1. Go to the **Actions** tab of the `example-application` repository
2. You should see the **Release and Deploy** workflow running
3. This will:
   - Build the Docker image
   - Push it to Docker Hub
   - Trigger the `update-deployment.yaml` workflow in `example-environment`
   - Create a pull request updating the manifest with the new image tag

### Step 4: Merge the Pull Request

1. Open the `example-environment` repository on GitHub
2. You should see an open PR titled something like `Deploy version v1.0.0`
3. Review and merge the PR into `main`

### Step 5: Watch Argo CD Sync Automatically

1. Open the Argo CD Web UI
2. Navigate to the `example-application` app
3. Within 3 - 5 minutes:
   - The app should detect the update
   - Show **OutOfSync** status briefly
   - Automatically sync and return to **Healthy**

### Summary

You have now successfully:

- Built and tagged a Docker image
- Automatically updated your Kubernetes manifest
- Verified Argo CD performed a GitOps deployment

Your full pipeline is now active and repeatable for future versions.

## Optional: Tune Argo CD Sync Interval

By default, Argo CD polls GitHub every 3 minutes for changes. If you want to reduce the sync interval (e.g., 60 seconds), follow these steps:

### Step 1: Add the Setting to the ConfigMap

Run:

```bash
kubectl -n argocd edit configmap argocd-cm
```

At the top of the `data:` section, add:

```
timeout.reconciliation: 60s
```

Save and exit.

### Step 2: Restart the ApplicationSet Controller

Run:

```bash
kubectl -n argocd rollout restart deployment argocd-applicationset-controller
```

This applies the updated polling interval.

### Step 3: Confirm It's Working

Make a small change to your manifest (like replicas or labels), push to `main`, and confirm that Argo auto-syncs within 60–90 seconds.

Your GitOps pipeline is now complete and optimized for faster feedback. You can iterate on your application confidently, knowing every change is tracked and deployed through code.

# Congratulations

Congratulations on completing the GitOps with GitHub Actions and Argo CD lab.

You've successfully built a complete GitOps pipeline, enabling continuous integration and continuous delivery of your containerized application. Here's what you accomplished:

- Used your existing EKS cluster with kubectl access
- Created two GitHub repositories: one for application code and another for deployment manifests
- Secured your automation using Docker Hub and GitHub repository secrets
- Built and pushed Docker images via GitHub Actions workflows
- Automatically updated Kubernetes manifests using a second GitHub Actions workflow
- Installed and configured Argo CD to watch your environment repository and sync changes to your cluster
- Triggered a release by tagging a version, confirming end-to-end deployment automation

You also explored optional tuning of Argo CD's sync interval to accelerate feedback cycles.

This lab reflects modern DevOps and platform engineering practices—fully automated, version-controlled, and observable from code to production. You're now well-equipped to extend this foundation with advanced GitOps capabilities.

Great work.