# AWS Kubernetes

AWS Kubernetes is a Kubernetes cluster deployed using [Kubeadm](https://kubernetes.io/docs/admin/kubeadm/) tool. It provides full integration with AWS. It is able to handle ELB load balancers, EBS disks, Route53 domains etc.

<!-- TOC -->

- [AWS Kubernetes](#aws-kubernetes)
    - [Updates](#updates)
    - [Prerequisites and dependencies](#prerequisites-and-dependencies)
    - [Including the module](#including-the-module)
    - [Add-ons](#addons)
    - [Custom add-ons](#custom-addons)
    - [Tagging](#tagging)

<!-- /TOC -->

## Updates

* *2.10.2022* Update to Kubernetes 1.25.2 + update add-ons
* *26.8.2022* Update to Kubernetes 1.25.0 + Calico upgrade
* *22.8.2022* Update to Kubernetes 1.24.4
* *16.7.2022* Update to Kubernetes 1.24.3
* *27.6.2022* Update to Kubernetes 1.24.2
* *11.6.2022* Update to Kubernetes 1.24.1 + update add-ons + remove dependency on the template provider
* *8.5.2022* Update to Kubernetes 1.24.0 + update add-ons
* *23.3.2022* Update to Kubernetes 1.23.5 + update add-ons
* *19.2.2022* Update to Kubernetes 1.23.4
* *12.2.2022* Update to Kubernetes 1.23.2
* *29.12.2021* Update to Kubernetes 1.23.1
* *11.12.2021* Update to Kubernetes 1.23.0

## Prerequisites and dependencies

* AWS Kubernetes deploys into existing VPC / public subnet. If you don't have your VPC / subnet yet, you can use [this](https://github.com/scholzj/terraform-aws-vpc) module to create one.
  * The VPC / subnet should be properly linked with Internet Gateway (IGW) and should have DNS and DHCP enabled.
  * Hosted DNS zone configured in Route53 (in case the zone is private you have to use IP address to copy `kubeconfig` and access the cluster).
* To deploy AWS Kubernetes there are no other dependencies apart from [Terraform](https://www.terraform.io). Kubeadm is used only on the EC2 hosts and doesn't have to be installed locally.

## Including the module

Although it can be run on its own, the main value is that it can be included into another Terraform configuration.

```hcl
module "kubernetes" {
  source = "scholzj/kubernetes/aws"

  aws_region    = "eu-central-1"
  cluster_name  = "aws-kubernetes"
  master_instance_type = "t2.medium"
  worker_instance_type = "t2.medium"
  ssh_public_key = "~/.ssh/id_rsa.pub"
  ssh_access_cidr = ["0.0.0.0/0"]
  api_access_cidr = ["0.0.0.0/0"]
  min_worker_count = 3
  max_worker_count = 6
  hosted_zone = "my-domain.com"
  hosted_zone_private = false

  master_subnet_id = "subnet-8a3517f8"
  worker_subnet_ids = [		
      "subnet-8a3517f8",
      "subnet-9b7853f7",
      "subnet-8g9sdfv8"
  ]
  
  # Tags
  tags = {
    Application = "AWS-Kubernetes"
  }

  # Tags in a different format for Auto Scaling Group
  tags2 = [
    {
      key                 = "Application"
      value               = "AWS-Kubernetes"
      propagate_at_launch = true
    }
  ]
  
  addons = [
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/storage-class.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/heapster.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/dashboard.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/external-dns.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/autoscaler.yaml"
  ]
}
```

An example of how to include this can be found in the [examples](examples/) dir.

## Add-ons

Currently, following add-ons are supported:
* Kubernetes dashboard
* Heapster for resource monitoring
* Storage class and CSI driver for automatic provisioning of persistent volumes
* External DNS (Replaces Route53 mapper)
* Ingress
* Autoscaler

The add-ons will be installed automatically based on the Terraform variables. 

## Custom add-ons

Custom add-ons can be added if needed. For every URL in the `addons` list, the initialization scripts will automatically call `kubectl -f apply <Addon URL>` to deploy it. The cluster is using RBAC. So the custom add-ons have to be *RBAC ready*.

## Tagging

If you need to tag resources created by your Kubernetes cluster (EBS volumes, ELB load balancers etc.) check [this AWS Lambda function which can do the tagging](https://github.com/scholzj/aws-kubernetes-tagging-lambda).
