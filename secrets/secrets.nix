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
  chatHosts = [
    zimbatm
    chat
  ];
in
{
  # no secrets defined yet — chatHosts is kept above for the next addition
}
