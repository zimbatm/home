# Join the self-hosted zero-deploy tailnet.
#
# Headscale lives on nibs-monitoring (Hetzner) and issues TLS certs from a
# self-signed root CA. This module trusts that CA, points tailscaled at
# Headscale's HTTPS endpoint, and pins the hostname → public IP since we
# don't have public DNS for nibs-monitoring.
#
# After enabling and rebuilding, run once:
#   ssh root@157.90.20.235  # or whichever cloud host you can reach
#   ssh root@nibs-monitoring 'headscale preauthkeys create --user 1 --reusable --expiration 24h'
#   sudo tailscale up --login-server https://nibs-monitoring:8080 --auth-key <key>
{ config, lib, pkgs, ... }:
{
  # Trust the zero-deploy root CA (matches infra/certs/root-ca.crt; copied
  # to ./certs/zero-root-ca.crt in this repo for self-containment).
  security.pki.certificateFiles = [
    ../../certs/zero-root-ca.crt
  ];

  # No public DNS for nibs-monitoring (yet); pin the host to the cloud IP
  # so the TLS SAN matches.
  networking.hosts = {
    "178.105.175.167" = [ "nibs-monitoring" ];
  };

  # tailscaled. No authKeyFile — operator runs `tailscale up` once and the
  # node sticks. extraUpFlags is empty so we don't fight a manual `up`.
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
  };
}
