{
  # Hetzner Cloud cx23 Debian-13 image actually boots BIOS (no /sys/firmware/efi).
  # GPT with a 1 MiB BIOS-boot partition so GRUB can install on a GPT disk.
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
