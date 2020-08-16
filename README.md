# AWS Kubernetes

AWS Kubernetes is a Kubernetes cluster deployed using [Kubeadm](https://kubernetes.io/docs/admin/kubeadm/) tool. It provides full integration with AWS. It is able to handle ELB load balancers, EBS disks, Route53 domains etc.

<!-- TOC -->

- [AWS Kubernetes](#aws-kubernetes)
    - [Updates](#updates)
    - [Prerequisites and dependencies](#prerequisites-and-dependencies)
    - [Including the module](#including-the-module)
    - [Addons](#addons)
    - [Custom addons](#custom-addons)
    - [Tagging](#tagging)

<!-- /TOC -->

## Updates

* *16.8.2020* Update to Kubernetes 1.18.8
* *20.6.2020* Update to Kubernetes 1.18.4, Update Kubernetes Dashboard to 2.0.2
* *26.4.2020* Update to Kubernetes 1.18.2, Update Kubernetes Dashboard to 2.0.0
* *12.4.2020* Update to Kubernetes 1.18.1
* *29.3.2020* Update to Kubernetes 1.18.0, update Dashboard and External DNS addons
* *21.3.2020* Update to Kubernetes 1.17.4
* *3.3.2020* Update to Kubernetes 1.17.3, update addons and Calico SDN
* *18.12.2019* Update to Kubernetes 1.17.0
* *24.11.2019* Update to Kubernetes 1.16.3
* *27.10.2019* Update to Kubernetes 1.16.2
* *6.10.2019* Update to Kubernetes 1.16.1
* *21.9.2019* Update to Kubernetes 1.16, update addons and Calico
* *24.8.2019* Update to Kubernetes 1.15.3, fix Ingress RBAC
* *7.8.2019* Update to Kubernetes 1.15.2
* *27.7.2019* Update to Kubernetes 1.15.1, upgrade addons and move to Terraform 0.12
* *9.6.2019* Update to Kubernetes 1.14.3
* *26.5.2019* Update to Kubernetes 1.14.2
* *17.4.2019* Update to Kubernetes 1.14.1
* *31.3.2019* Update to Kubernetes 1.14.0, Ingress 0.23.0, External DNS 0.5.12, Calico 3.6.1
* *2.3.2019* Update to Kubernetes 1.13.4 ([CVE-2019-1002100](https://github.com/kubernetes/kubernetes/issues/74534))
* *3.2.2019* Update to Kubernetes 1.13.3
* *19.1.2019* Update to Kubernetes 1.13.2
* *28.12.2018* Update Kubernetes Dashboard to 1.10.1
* *17.12.2018* Update to Kubernetes 1.13.1 and Calico 3.4.0
* *8.12.2018:* Update to Kubernetes 1.13.0, added storage class for `st1` HDD disks, Ingress 0.21.0 and Cluster Autoscaler 1.13.0
* *1.12.2018:* Update to Kubernetes 1.12.3 and External DNS 0.5.9
* *12.11.2018:* Make it possible to use only private IPs ([#19](https://github.com/scholzj/terraform-aws-minikube/pull/19))
* *11.11.2018:* Fix error when updating ASG launch-configurations (#20)
* *10.11.2018* Update to Kubernetes 1.12.2, Calico 3.3 and addons (Dashboard 1.10.0, Heapster 1.5.4, Ingress 0.20.0, External DNS 0.5.8, Cluster Autoscaler 1.12.1)
* *28.6.2018:* Fix error when disabling already disabled SE Linux ([#1](https://github.com/scholzj/terraform-aws-minikube/pull/1))
* *23.6.2018:* Update to Kubernetes 1.10.5
* *8.6.2018:* Update to Kubernetes 1.10.4
* *27.5.2018:* Update to Kubernetes 1.10.3 and Cluster Autoscaler 1.2.2
* *29.4.2018:* Update to Kubernetes 1.10.2
* *18.4.2018:* Update to Kubernetes 1.10.1
* *31.3.2018:* Update to Kubernetes 1.10.0, update Calico networking and update Kubernetes Dahsboard, Cluster Autoscaler, Ingress and Heapster addons
* *24.3.2018:* Update to Kubernetes 1.9.6
* *17.3.2018:* Update to Kubernetes 1.9.4
* *11.3.2018:* Fix further issues with Cluster Autoscaler
* *4.3.2018:* Fix issues with Cluster Autoscaler not scaling down nodes
* *11.2.2018:* Update to Kubernetes 1.9.3 and Cluster Autoscaler to 1.1.1
* *29.1.2018:* Add `kubernetes.io/cluster/my-kubernetes` tag also to the master subnet
* *22.1.2018:* Update Calico to 3.0.1
* *22.1.2018:* Update to Kubernetes 1.9.2, Ingres 0.10.0 and Dashboard 1.8.2
* *6.1.2018:* Update to Kubernetes 1.9.1
* *17.12.2017:* Update to Kubernetes 1.9.0, update Dashboard, Ingress, Autoscaler and Heapster dependencies
* *8.12.2017:* Update to Kubernetes 1.8.5
* *1.12.2017:* Fix problems with incorrect Ingress RBAC rights
* *28.11.2017:* Update addons (Cluster Autoscaler, Heapster, Ingress, Dashboard, External DNS)
* *23.11.2017:* Update to Kubernetes 1.8.4
* *9.11.2017:* Update to Kubernetes 1.8.3
* *4.11.2017:* Update to Kubernetes 1.8.2
* *14.10.2017:* Update to Kubernetes 1.8.1 and fix bug with passing subnet IDs list
* *30.9.2017:* Update to Kubernetes 1.8
* *28.9.2017:* Split into module and configuration; update addon versions
* *22.8.2017:* Update Kubernetes and Kubeadm to 1.7.4
* *30.8.2017:* New addon - Fluentd + ElasticSearch + Kibana
* *2.9.2017:* Update Kubernetes and Kubeadm to 1.7.5

## Prerequisites and dependencies

* AWS Kubernetes deployes into existing VPC / public subnet. If you don't have your VPC / subnet yet, you can use [this](https://github.com/scholzj/terraform-aws-vpc) module to create one.
  * The VPC / subnet should be properly linked with Internet Gateway (IGW) and should have DNS and DHCP enabled.
  * Hosted DNS zone configured in Route53 (in case the zone is private you have to use IP address to copy kubeconfig and access the cluster).
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

## Addons

Currently, following addons are supported:
* Kubernetes dashboard
* Heapster for resource monitoring
* Storage class for automatic provisioning of persistent volumes
* External DNS (Replaces Route53 mapper)
* Ingress
* Autoscaler

The addons will be installed automatically based on the Terraform variables. 

## Custom addons

Custom addons can be added if needed. For every URL in the `addons` list, the initialization scripts will automatically call `kubectl -f apply <Addon URL>` to deploy it. The cluster is using RBAC. So the custom addons have to be *RBAC ready*.

## Tagging

If you need to tag resources created by your Kubernetes cluster (EBS volumes, ELB load balancers etc.) check [this AWS Lambda function which can do the tagging](https://github.com/scholzj/aws-kubernetes-tagging-lambda).
