# Change NixOS a bit to make it more compatible with Ubuntu.
#
# Also run this at the first time:
# * sudo mkdir /lib64
# * sudo ln -s /run/current-system/sw/lib/ld-linux-x86-64.so.2 /lib64/
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.glibc.out
  ];
}
