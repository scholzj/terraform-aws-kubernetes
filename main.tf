#####
# AWS Prodvider
#####

# Retrieve AWS credentials from env variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
provider "aws" {
  alias  = "kubernetes"
  region = "${var.aws_region}"

  assume_role {
    session_name = "Terraform"
    role_arn     = "${var.aws_role_arn}"
  }
}

#####
# Generate kubeadm token
#####

module "kubeadm-token" {
  source = "scholzj/kubeadm-token/random"
}

#####
# IAM roles
#####

# Master

data "template_file" "master_policy_json" {
  template = "${file("${path.module}/template/master-policy.json.tpl")}"

  vars {}
}

resource "aws_iam_policy" "master_policy" {
  provider    = "aws.kubernetes"
  name        = "${var.cluster_name}-master"
  path        = "/"
  description = "Policy for role ${var.cluster_name}-master"
  policy      = "${data.template_file.master_policy_json.rendered}"
}

resource "aws_iam_role" "master_role" {
  provider           = "aws.kubernetes"
  name               = "${var.cluster_name}-master"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "master-attach" {
  provider   = "aws.kubernetes"
  name       = "master-attachment"
  roles      = ["${aws_iam_role.master_role.name}"]
  policy_arn = "${aws_iam_policy.master_policy.arn}"
}

resource "aws_iam_instance_profile" "master_profile" {
  provider = "aws.kubernetes"
  name     = "${var.cluster_name}-master"
  role     = "${aws_iam_role.master_role.name}"
}

# Node

data "template_file" "node_policy_json" {
  template = "${file("${path.module}/template/node-policy.json.tpl")}"

  vars {}
}

resource "aws_iam_policy" "node_policy" {
  provider    = "aws.kubernetes"
  name        = "${var.cluster_name}-node"
  path        = "/"
  description = "Policy for role ${var.cluster_name}-node"
  policy      = "${data.template_file.node_policy_json.rendered}"
}

resource "aws_iam_role" "node_role" {
  provider           = "aws.kubernetes"
  name               = "${var.cluster_name}-node"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "node-attach" {
  provider   = "aws.kubernetes"
  name       = "node-attachment"
  roles      = ["${aws_iam_role.node_role.name}"]
  policy_arn = "${aws_iam_policy.node_policy.arn}"
}

resource "aws_iam_instance_profile" "node_profile" {
  provider = "aws.kubernetes"
  name     = "${var.cluster_name}-node"
  role     = "${aws_iam_role.node_role.name}"
}

#####
# Security Group
#####

# Find VPC details based on Master subnet
data "aws_subnet" "cluster_subnet" {
  provider = "aws.kubernetes"
  id       = "${var.master_subnet_id}"
}

resource "aws_security_group" "kubernetes" {
  provider = "aws.kubernetes"
  vpc_id   = "${data.aws_subnet.cluster_subnet.vpc_id}"
  name     = "${var.cluster_name}"
  tags     = "${merge(map("Name", var.cluster_name, format("kubernetes.io/cluster/%v", var.cluster_name), "owned"), var.tags)}"
}

# Allow outgoing connectivity
resource "aws_security_group_rule" "allow_all_outbound_from_kubernetes" {
  provider          = "aws.kubernetes"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.kubernetes.id}"
}

# Allow SSH connections only from specific CIDR (TODO)
resource "aws_security_group_rule" "allow_ssh_from_cidr" {
  provider          = "aws.kubernetes"
  count             = "${length(var.ssh_access_cidr)}"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.ssh_access_cidr[count.index]}"]
  security_group_id = "${aws_security_group.kubernetes.id}"
}

# Allow the security group members to talk with each other without restrictions
resource "aws_security_group_rule" "allow_cluster_crosstalk" {
  provider                 = "aws.kubernetes"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.kubernetes.id}"
  security_group_id        = "${aws_security_group.kubernetes.id}"
}

# Allow API connections only from specific CIDR (TODO)
resource "aws_security_group_rule" "allow_api_from_cidr" {
  provider          = "aws.kubernetes"
  count             = "${length(var.api_access_cidr)}"
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["${var.api_access_cidr[count.index]}"]
  security_group_id = "${aws_security_group.kubernetes.id}"
}

##########
# Bootstraping scripts
##########

data "template_file" "init_master" {
  template = "${file("${path.module}/scripts/init-aws-kubernetes-master.sh")}"

  vars {
    kubeadm_token = "${module.kubeadm-token.token}"
    dns_name      = "${var.cluster_name}.${var.hosted_zone}"
    ip_address    = "${aws_eip.master.public_ip}"
    cluster_name  = "${var.cluster_name}"
    addons        = "${join(" ", var.addons)}"
    aws_region    = "${var.aws_region}"
    asg_name      = "${var.cluster_name}-nodes"
    asg_min_nodes = "${var.min_worker_count}"
    asg_max_nodes = "${var.max_worker_count}"
    aws_subnets   = "${join(" ", var.worker_subnet_ids)}"

  }
}

data "template_file" "init_node" {
  template = "${file("${path.module}/scripts/init-aws-kubernetes-node.sh")}"

  vars {
    kubeadm_token = "${module.kubeadm-token.token}"
    dns_name      = "${var.cluster_name}.${var.hosted_zone}"
  }
}

data "template_file" "cloud_init_config" {
  template = "${file("${path.module}/scripts/cloud-init-config.yaml")}"

  vars {
    calico_yaml = "${base64gzip("${file("${path.module}/scripts/calico.yaml")}")}"
  }
}

data "template_cloudinit_config" "master_cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-init-config.yaml"
    content_type = "text/cloud-config"
    content      = "${data.template_file.cloud_init_config.rendered}"
  }

  part {
    filename     = "init-aws-kubernete-master.sh"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.init_master.rendered}"
  }
}

data "template_cloudinit_config" "node_cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init-aws-kubernetes-node.sh"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.init_node.rendered}"
  }
}

##########
# Keypair
##########

resource "aws_key_pair" "keypair" {
  provider   = "aws.kubernetes"
  key_name   = "${var.cluster_name}"
  public_key = "${file(var.ssh_public_key)}"
}

#####
# AMI image
#####

data "aws_ami_ids" "centos7" {
  provider = "aws.kubernetes"
  owners   = ["aws-marketplace"]

  filter {
    name   = "product-code"
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#####
# Master - EC2 instance
#####

resource "aws_eip" "master" {
  provider = "aws.kubernetes"
  vpc      = true
}

resource "aws_instance" "master" {
  provider                    = "aws.kubernetes"
  instance_type               = "${var.master_instance_type}"
  ami                         = "${data.aws_ami_ids.centos7.ids[0]}"
  key_name                    = "${aws_key_pair.keypair.key_name}"
  subnet_id                   = "${var.master_subnet_id}"
  associate_public_ip_address = false
  vpc_security_group_ids      = ["${aws_security_group.kubernetes.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.master_profile.name}"
  user_data                   = "${data.template_cloudinit_config.master_cloud_init.rendered}"

  tags = "${merge(map("Name", join("-", list(var.cluster_name, "master")), format("kubernetes.io/cluster/%v", var.cluster_name), "owned"), var.tags)}"

  root_block_device {
      volume_type = "gp2"
      volume_size = "50"
      delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [
      "ami",
      "user_data",
      "associate_public_ip_address"
    ]
  }
}

resource "aws_eip_association" "master_assoc" {
  provider      = "aws.kubernetes"
  instance_id   = "${aws_instance.master.id}"
  allocation_id = "${aws_eip.master.id}"
}

#####
# Nodes
#####

resource "aws_launch_configuration" "nodes" {
  provider                    = "aws.kubernetes"
  name                        = "${var.cluster_name}-nodes"
  image_id                    = "${data.aws_ami_ids.centos7.ids[0]}"
  instance_type               = "${var.worker_instance_type}"
  key_name                    = "${aws_key_pair.keypair.key_name}"
  iam_instance_profile        = "${aws_iam_instance_profile.node_profile.name}"
  security_groups             = ["${aws_security_group.kubernetes.id}"]
  associate_public_ip_address = true
  user_data                   = "${data.template_cloudinit_config.node_cloud_init.rendered}"

  root_block_device {
      volume_type = "gp2"
	    volume_size = "50"
	    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      "user_data"
    ]
  }
}

resource "aws_autoscaling_group" "nodes" {
  provider             = "aws.kubernetes"
  vpc_zone_identifier  = ["${var.worker_subnet_ids}"]
  name                 = "${var.cluster_name}-nodes"
  max_size             = "${var.max_worker_count}"
  min_size             = "${var.min_worker_count}"
  desired_capacity     = "${var.min_worker_count}"
  launch_configuration = "${aws_launch_configuration.nodes.name}"

  tags = [{
    key = "Name"
    value = "${var.cluster_name}-node"
    propagate_at_launch = true
  }]

  tags = [{
    key = "kubernetes.io/cluster/${var.cluster_name}"
    value = "owned"
    propagate_at_launch = true
  }]

  tags = ["${var.tags2}"]
}

#####
# DNS record
#####

data "aws_route53_zone" "dns_zone" {
  provider     = "aws.kubernetes"
  name         = "${var.hosted_zone}."
  private_zone = "${var.hosted_zone_private}"
}

resource "aws_route53_record" "master" {
  provider = "aws.kubernetes"
  zone_id  = "${data.aws_route53_zone.dns_zone.zone_id}"
  name     = "${var.cluster_name}.${var.hosted_zone}"
  type     = "A"
  records  = ["${aws_eip.master.public_ip}"]
  ttl      = 300
}
