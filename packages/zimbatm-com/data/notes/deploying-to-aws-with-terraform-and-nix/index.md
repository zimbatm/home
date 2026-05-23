---
title: Deploying to AWS with Terraform and Nix
created: '2020-05-23'
updated: '2022-01-05'
date: '2020-05-23'
tags:
- Terraform
- Nix
---

Let's say that you want to deploy this NixOS configuration onto AWS:

`configuration.nix`

```nix
{ ... }:
{
  # Put your NixOS configuration here. Eg:
  services.nginx.enable = true;
}
```

The first thing to do is to create another NixOS configuration that includes the amazon-image config and your main config. This is what ultimately is going to end-up on the VM:

`aws-deploy.nix`

```nix
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    # path to your config
    ./configuration.nix
  ];
}
```

TODO: Setup CI here and Eval NixOS to pre-fill the cache.

With that in hand, we can now write a bit of Terraform code:

```plain text
variable "name" {
  description = "Name prefix"
}

# Generate a SSH key-pair
resource "tls_private_key" "machine" {
  algorithm = "RSA"
}

# Record the SSH public key into AWS
resource "aws_key_pair" "machine" {
  key_name   = var.name
  public_key = tls_private_key.machine.public_key_openssh
}

# Store the private key locally. This is going to be used by the deploy_nixos module below
# to deploy NixOS.
resource "local_file" "machine_ssh_key" {
  sensitive_content = tls_private_key.machine.private_key_pem
  filename          = "${path.module}/id_rsa.pem"
  file_permission   = "0600"
}

# This is the security group that will be attached to the instance
resource "aws_security_group" "machine" {
  name = var.name
}

# A bunch of rules for the group
resource "aws_security_group_rule" "machine_ingress_ssh" {
  description       = "Allow SSH from everywhere"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.machine.id
}

resource "aws_security_group_rule" "machine_ingress_http" {
  description              = "Allow HTTP from everywhere"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = aws_security_group.machine.id
}

resource "aws_security_group_rule" "machine_egress_all" {
  description       = "Allow to connect to the whole Internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.machine.id
}

# Permissions for the AWS instance
data "aws_iam_policy_document" "machine" {
  statement {
    sid = "1"

    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }
}

# A bunch of IAM resources needed to give permissions to the instance
resource "aws_iam_role" "machine" {
  name = var.name

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

resource "aws_iam_role_policy" "machine" {
  name   = var.name
  role   = aws_iam_role.machine.name
  policy = data.aws_iam_policy_document.machine.json
}

resource "aws_iam_instance_profile" "machine" {
  name       = var.name
  role       = aws_iam_role.machine.name
  depends_on = [aws_iam_role_policy.machine]
}

# The actual AWS instance
resource "aws_instance" "machine" {
  # Base image to start the instance with
  ami                  = module.nixos_image.ami
  iam_instance_profile = aws_iam_instance_profile.machine.id
  instance_type        = "c5.large"
  key_name             = aws_key_pair.machine.key_name
  security_groups      = [aws_security_group.machine.name]
  tags                 = { "Name" = var.name }

  root_block_device {
    volume_type = "gp2"
    volume_size = "50" # GiB
  }

  lifecycle {
    create_before_destroy = true
  }
}

# This deploys the NixOS configuration onto the VM
module "machine_deploy" {
  source = "git@github.com:tweag/terraform-nixos.git//deploy_nixos?ref=dbba649db86d90166d7573bb60ba40ac790e17d1"

  # FIXME: pin nixpkgs
  # NIX_PATH = "nixpkgs=${path.module}/../../nix/nixpkgs.nix"
  nixos_config = "${path.module}/configuration.nix"

  target_host          = aws_instance.machine.public_ip
  target_user          = "root"
  ssh_private_key_file = local_file.machine_ssh_key.filename

  triggers = {
    # Force a new deployment if the instance ID has changed. The ID changes if
    # the instance is re-created for example.
    machine_id = aws_instance.machine.id
  }
}
```

## Downsides

- No auto-scaling: only a single VM gets configured
- No auto-healing: if the VM goes down, it takes another `terraform apply` to re-deploy the system configuration.

## Upsides

- Simple setup.
- Direct feedback on deployment.
- It's easy to migrate this auto-scaling in the future.

## TODO

- Use CI + Cachix to pre-build the NixOS machine.
- Write a terraform aws_image_nixos_custom module for auto-scaling scenarios.
- Secret management → use SSM
- Better SSH key management?
