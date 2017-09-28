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
    "https://s3.amazonaws.com/scholzj-kubernetes/cluster/addons/storage-class.yaml",
    "https://s3.amazonaws.com/scholzj-kubernetes/cluster/addons/heapster.yaml",
    "https://s3.amazonaws.com/scholzj-kubernetes/cluster/addons/dashboard.yaml",
    "https://s3.amazonaws.com/scholzj-kubernetes/cluster/addons/external-dns.yaml",
    "https://s3.amazonaws.com/scholzj-kubernetes/cluster/addons/autoscaler.yaml"
  ]

  
}