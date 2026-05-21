{
  # UEFI GPT layout for Hetzner Cloud cx42 (AMD x86, 8c/16GB/160GB). Same
  # shape as mail (cpx22) — newer Hetzner types ship UEFI by default. 512 MiB
  # ESP at /boot, rest ext4 root. systemd-boot installs to the ESP.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
