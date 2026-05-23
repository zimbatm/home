---
name: zimbatm.com
base_url: https://zimbatm.com
collections:
- name: notes
  path: /notes
  template: article.html
  list_template: list.html
  sort_by: date
  sort_order: desc
- name: projects
  path: /projects
  template: project.html
  list_template: project-list.html
  sort_by: status
  sort_values: [Alpha, Beta, Stable, Done]
  group_by: status
  group_sort_by: created
  group_sort_order: desc
pages:
- source: landing.md
  path: /
  template: landing.html
  base_template: base-landing.html
feeds:
- collection: notes
  path: /notes/feed.xml
  title: zimbatm's notes
  description: Notes on software engineering, Nix, and other topics
  limit: 20
aliases:
- from: /NixFlakes
  to: /notes/summary-of-nix-flakes-vs-original-nix
- from: /NixFriday
  to: /projects/nixfriday
- from: /notes/nix-26-eval-improvement/nix-build-pkgstop-levelreleasenix-a-metrics
  to: /notes/nix-26-eval-improvement
- from: /notes/nix-26-eval-improvement/nix-build-pkgstop-levelreleasenix-a-metrics/nix-envqavalues
  to: /notes/nix-26-eval-improvement
- from: /notes/nix-26-eval-improvement/nix-build-pkgstop-levelreleasenix-a-metrics/nixoskdeallocations
  to: /notes/nix-26-eval-improvement
- from: /notes/nix-26-eval-improvement/nix-build-pkgstop-levelreleasenix-a-metrics/nixoslapptime
  to: /notes/nix-26-eval-improvement
- from: /the-nix-configuration
  to: /notes/the-nix-configuration
- from: /enrolling-existing-aws-account-in-controltower-awscontroltowerexecution-iam-role
  to: /notes/enrolling-existing-aws-account-in-controltower-awscontroltowerexecution-iam-role
- from: /old-projects/github-deploy
  to: /projects/github-deploy
- from: /old-projects/nixbox
  to: /projects/nixbox
- from: /old-projects/nixcon-2018
  to: /projects/nixcon-2018
- from: /old-projects/nixcon-2019
  to: /projects/nixcon-2019
- from: /old-projects/nixfriday
  to: /projects/nixfriday
- from: /old-projects/socketmaster
  to: /projects/socketmaster
- from: /old-projects/terraform-nixos
  to: /projects/terraform-nixos
- from: /old-projects
  to: /projects
---

View configuration for zimbatm.com personal website.
