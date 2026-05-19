{
  # BIOS GPT layout for Hetzner Cloud cx23. 1 MiB BIOS-boot for GRUB, single
  # ext4 root. Hetzner Cloud Volumes are external and intentionally NOT in
  # disko — disko would otherwise wipe them.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
          priority = 1;
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
