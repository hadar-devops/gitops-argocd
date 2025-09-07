
---

## 2) **gitops-argocd-apps/README.md**

```markdown
# GitOps: ArgoCD Applications & Bootstrap

This repository contains **ArgoCD Application and ApplicationSet manifests** used to deploy the WeatherApp.  
It also includes a `deploy.sh` script to install ArgoCD into the EKS cluster created by the infra repo.

---

## Usage

1. Make sure you have already run `terraform apply` in [infra-aws-eks-argocd](https://github.com/your-org/infra-aws-eks-argocd).
2. Copy the **VPC ID** output from Terraform.
3. Run the bootstrap script:

```bash
bash deploy.sh <your-vpc-id>
```

This installs ArgoCD and registers the GitOps Applications.

Project Flow:

1.Terraform creates the EKS cluster in the infra repo.

2.This repo installs ArgoCD into the cluster with deploy.sh.

3.The VPC ID from Terraform is passed as input to configure ingress properly.

4.ArgoCD continuously watches the helm-weatherapp-chart
