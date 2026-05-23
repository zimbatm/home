---
title: Enrolling existing AWS Account in ControlTower - AWSControlTowerExecution IAM
  role
created: '2022-08-10'
updated: '2022-08-10'
date: '2022-08-10'
tags:
- Engineering notes
---

Hopefully, this page gets indexed on Google for the next person.

This is for people enabling AWS Control Tower on an existing AWS Organization.

AWS provides documentation on [how to enroll existing AWS accounts](https://docs.aws.amazon.com/controltower/latest/userguide/enroll-account.html). They mention that the old AWS accounts need an `AWSControlTowerExecution` role. And then never tells you how to create one.

So here is how:

- Log into the account that needs to be enrolled.
- IAM →Roles → Create Role
- Select trusted entity: AWS Account → Another AWS account. Enter the Management AWS Account ID → Next
- Add permissions: AdministratorAccess ( `arn:aws:iam::aws:policy/AdministratorAccess` ) → Next
- Name, review, and create:
  - Role name: AWSControlTowerExecution
  - Create role

Simple in retrospect
