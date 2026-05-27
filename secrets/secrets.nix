# agenix secrets manifest. To add a secret:
#   {
#     "foo.age".publicKeys = chatHosts;  # list of recipients (user + host)
#   }
# Then create with: agenix -e secrets/foo.age
#
# Don't convert SSH host keys via ssh-to-age — list the raw `ssh-ed25519 AAAA...`
# string. Converting produces an X25519 recipient that the SSH private key on
# the host can't unwrap, and decryption silently fails.
let
  zimbatm = "age1tk655t40a4zx7ry0mzj57vmw4xpr7sa0c8qnckmclj5gzjls4yzsk7weg0";
  chat = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBblE/Tba4Zpfic7CV67CM7vJOsOnDQC+HPCl25zs7Y";
  web2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGj0tVR0yzuGR+HBoXh6HqUQOH3JHNUlKQM4/t74r3Gz";
  mc1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFhNSteHsLGklQ6WfEuTl+jcWY10YxB9MTktVyjrvQ1O";
  agents = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAION9fEQJzwaGn7LzRiRWf9sGAU0hgRd2DtaMOm/DXr+F";
  nv1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRCwb2rpKwjTY2PrhkkI4mke15nziZb2z8NGD/IsrcE";

  # `agents` is a universal recovery recipient: every secret is also
  # encrypted to its SSH host key so that if the laptop's age key
  # (~/.config/sops/age/keys.txt on nv1) is lost, we can still decrypt
  # by `ssh root@agents.ztm.io -i <hostkey> agenix -d <file>`. Don't
  # remove it without thinking through the rotation cost: stripping
  # `agents` from every recipient list means losing the backup.
  recovery = [ agents ];

  nv1Hosts     = [ zimbatm nv1 ]    ++ recovery;
  agentsHosts  = [ zimbatm agents ];
  chatHosts    = [ zimbatm chat ]   ++ recovery;
  web2Hosts    = [ zimbatm web2 ]   ++ recovery;
  mc1Hosts     = [ zimbatm mc1 ]    ++ recovery;
in
{
  "web2-restic-password.age".publicKeys = web2Hosts;
  "web2-restic-ssh-key.age".publicKeys = web2Hosts;
  "chat-restic-password.age".publicKeys = chatHosts;
  "chat-restic-ssh-key.age".publicKeys = chatHosts;
  "matrix-numtide-password.age".publicKeys = chatHosts;
  "mc1-restic-password.age".publicKeys = mc1Hosts;
  "mc1-restic-ssh-key.age".publicKeys = mc1Hosts;
  "hc-ping-weechat.age".publicKeys = chatHosts;
  "hc-ping-gotosocial.age".publicKeys = web2Hosts;
  "hc-ping-minecraft.age".publicKeys = mc1Hosts;
  "tinc-ztm-nv1-key.age".publicKeys = nv1Hosts;
  "tinc-ztm-chat-key.age".publicKeys = chatHosts;
  "tinc-ztm-web2-key.age".publicKeys = web2Hosts;
  "tinc-ztm-mc1-key.age".publicKeys = mc1Hosts;
  "tinc-ztm-agents-key.age".publicKeys = agentsHosts;
  # Pocket ID lives on `web2` since #82.
  "pocket-id-encryption-key.age".publicKeys = web2Hosts;
  "pocket-id-static-api-key.age".publicKeys = web2Hosts ++ [ agents ];
  "oauth2-proxy-agents-cookie.age".publicKeys = agentsHosts;
}
