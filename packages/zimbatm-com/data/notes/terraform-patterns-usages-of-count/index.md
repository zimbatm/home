---
title: 'Terraform patterns: usages of count'
created: '2019-01-27'
updated: '2022-01-05'
date: '2022-01-02'
tags:
- Terraform
---

> count (int) - The number of identical resources to create. This doesn’t apply to all resources. For details on using variables in conjunction with count, see Using Variables with count below.

TL;DR: only use the `count` attribute to enable resources.

## Basic example

The `count` attribute can be used to instantiate multiple resources with a single resource declaration. Here we instanciate 10 EC2 instances:

Eg:

```plain text
resource "aws_instance" "web" {
  count         = 10
  ami           = "ami-0cdba8e998f076547"
  instance_type = "t2.micro"
}
```

On the surface it looks useful but it suffers from a number of limitations that make it almost useless.

## Pattern: `enable` attribute

This is pretty much the only viable use-case for the `count` attribute. Use `count = 0` to disable a resource and `count = 1` to enable it.

Even then, evaluation might fail if the resource is disabled and another resource depends on it’s outputs.

Eg:

```plain text
variable "enable_elb" {
  default = 1
}

resource "aws_elb" "bar" {
  count              = "${var.enable_elb}"
  name               = "foobar-terraform-elb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  instances                   = ["${aws_instance.web.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}
```

## Anti-pattern: avoid repetition

Forget DRY with Terraform. Copy-and-paste is your friend :slight_smile:

This is a natural usage of `count`. Don’t do this:

```plain text
variable "users" {
  type = "list"
}

resource "aws_iam_user" "my-users" {
  count = "${length(var.users)}"
  name = "${element(var.users, count.index)}"
  path = "/"
}
```

Let’s say I instantiace that module with:

```plain text
module "my-users" {
  source = "../tf_my_users"
  users = [
    "bob",
    "alice",
    "jannet",
  ]
}
```

This will work great on the first invocation. The problem is that each `aws_iam_user` is actually a different resource.

Let’s say that later that `bob` leaves the company.

```plain text
aws_iam_user.my-users.0 "bob" => "alice"
aws_iam_user.my-users.1 "alice" => "jannet"
aws_iam_user.my-users.2 "jannet" => ""
```

All the users get re-created, invalidating their AWS credentials. With bad luck your current AWS account might be in that list.

So in conclusion, Terraform deals with individual resources. Having them tied to a specific ordering is quite a bad idea as it makes the application of those resource inflexible.

For that use-case it’s better to copy-and-paste the IAM user. Or write a script that generates the terraform code from the list of users.
