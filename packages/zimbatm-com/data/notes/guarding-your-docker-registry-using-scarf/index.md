---
title: Guard your project's Docker registry using Scarf and a custom domain
aliases:
- /notes/guard-your-projects-docker-registry-using-scarf-and-a-custom-domain
created: '2023-03-26'
updated: '2023-03-26'
tags:
- Engineering notes
---

On March 14th, Docker Inc. informed us via email that they would no longer offer the Docker Hub Free Team plan. We had 30 days to pay $420 per year or else our organization would be deleted.

However, moving registries without causing disruption takes a long time. There is always a long tail of users that depend on the current location, buried in 20 layers of scripts or recursive Dockerfiles. Projects were being held hostage in some way.

Because Numtide worked with [Scarf](https://scarf.sh/) before, I had migrated [https://github.com/nix-community/docker-nixpkgs](https://github.com/nix-community/docker-nixpkgs) to it, and had it bound to a custom domain; docker.nix-community.org. So while all the other projects were scrambling away, all I had to do, is redirect the domain to a different registry. The only caveat that I found is that the images must live on the same path prefix, due to a limitation of the docker registry protocol.

In the end, Docker Inc. reverted their stance, but that is a good reminder; if you don’t control the domain, you don’t control the project. It was nice to be able to sit back and relax while all the other projects were scambling away.

<details>
<summary>What is Scarf?</summary>
  [Scarf](https://scarf.sh/) is a SaaS company that provides high-level insights about your project downloads. It’s useful for finding out which company is using your project.

</details>
