{
  # Hetzner Cloud cpx51 — 360 GB root disk, BIOS-boot. Single ext4 root,
  # 1 MiB BIOS-boot partition for GRUB on GPT. No volumes (yet); if we ever
  # need them for a build cache or scratch space, attach + mount alongside.
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
