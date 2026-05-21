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
  mail = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHXTqRXCrgBb03kQOsilzkCwaVgdUHpggIZwhNX6XZcM";
  # mc1 host pubkey — fill in after provisioning (see machines/mc1/README.md
  # for the bootstrap dance), then re-run `agenix -r` on the mc1 secrets.
  # mc1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... root@mc1";

  chatHosts = [
    zimbatm
    chat
  ];
  web2Hosts = [
    zimbatm
    web2
  ];
  mailHosts = [
    zimbatm
    mail
  ];
  mc1Hosts = [
    zimbatm
    # mc1
  ];
in
{
  "web2-restic-password.age".publicKeys = web2Hosts;
  "web2-restic-ssh-key.age".publicKeys = web2Hosts;
  "stalwart-admin-secret.age".publicKeys = mailHosts;
  "stalwart-zimbatm-password.age".publicKeys = mailHosts;
  "calendar-publish-token.age".publicKeys = mailHosts;
  "stalwart-jonas-password.age".publicKeys = mailHosts;
  "mail-restic-password.age".publicKeys = mailHosts;
  "mail-restic-ssh-key.age".publicKeys = mailHosts;
  "chat-restic-password.age".publicKeys = chatHosts;
  "chat-restic-ssh-key.age".publicKeys = chatHosts;
  "matrix-numtide-password.age".publicKeys = chatHosts;
  "mc1-restic-password.age".publicKeys = mc1Hosts;
  "mc1-restic-ssh-key.age".publicKeys = mc1Hosts;
}
