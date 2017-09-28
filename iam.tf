#####
# IAM role
#####

# Master

data "template_file" "master_policy_json" {
  template = "${file("${path.module}/template/master-policy.json.tpl")}"

  vars {}
}

resource "aws_iam_policy" "master_policy" {
  name        = "${var.cluster_name}-master"
  path        = "/"
  description = "Policy for role ${var.cluster_name}-master"
  policy      = "${data.template_file.master_policy_json.rendered}"
}

resource "aws_iam_role" "master_role" {
  name = "${var.cluster_name}-master"

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
  name       = "master-attachment"
  roles      = ["${aws_iam_role.master_role.name}"]
  policy_arn = "${aws_iam_policy.master_policy.arn}"
}

resource "aws_iam_instance_profile" "master_profile" {
  name  = "${var.cluster_name}-master"
  role = "${aws_iam_role.master_role.name}"
}

# Node

data "template_file" "node_policy_json" {
  template = "${file("${path.module}/template/node-policy.json.tpl")}"

  vars {}
}

resource "aws_iam_policy" "node_policy" {
  name        = "${var.cluster_name}-node"
  path        = "/"
  description = "Policy for role ${var.cluster_name}-node"
  policy      = "${data.template_file.node_policy_json.rendered}"
}

resource "aws_iam_role" "node_role" {
  name = "${var.cluster_name}-node"

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
  name       = "node-attachment"
  roles      = ["${aws_iam_role.node_role.name}"]
  policy_arn = "${aws_iam_policy.node_policy.arn}"
}

resource "aws_iam_instance_profile" "node_profile" {
  name  = "${var.cluster_name}-node"
  role = "${aws_iam_role.node_role.name}"
}