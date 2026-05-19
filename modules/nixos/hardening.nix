# Shared hardening for server hosts (chat, web2). Don't import on nv1 —
# the userns / dmesg restrictions break Flatpak, rootless podman, and
# debugging.
{ ... }:
{
  # ---------------------------------------------------------------------------
  # Kernel attack surface
  # ---------------------------------------------------------------------------
  #
  # Blacklisting unused kernel modules. The legacy filesystems and exotic
  # network protocols below have a steady drip of memory-safety CVEs (the
  # "copy.fail" wave being the recent one) and none of them are used on these
  # hosts. blacklistedKernelModules prevents both auto-load on bus events and
  # explicit modprobe.
  boot.blacklistedKernelModules = [
    # Legacy / rarely-used filesystems with a CVE history
    "cramfs"
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
    "udf"
    "f2fs"

    # Legacy / niche network protocols (broad net-stack surface)
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "n-hdlc"
    "ax25"
    "netrom"
    "x25"
    "rose"
    "decnet"
    "econet"
    "af_802154"
    "ipx"
    "appletalk"
    "psnap"
    "p8023"
    "p8022"

    # Unused hot-plug storage / interconnects
    "firewire-core"
    "firewire-ohci"
    "firewire-sbp2"
    "thunderbolt"

    # Test driver with public exploit history
    "vivid"
  ];

  # ---------------------------------------------------------------------------
  # sysctl knobs
  # ---------------------------------------------------------------------------
  boot.kernel.sysctl = {
    # Note: `kernel.unprivileged_userns_clone` is a Debian-only knob and
    # doesn't exist on mainline. The equivalent global kill-switch is
    # `user.max_user_namespaces = 0`, but it's too aggressive — breaks
    # any service relying on `PrivateUsers=true`. Skipping; rely on
    # per-service sandboxing instead.

    # Hide kernel pointers from /proc — defangs many infoleak primitives.
    "kernel.kptr_restrict" = 2;

    # dmesg is root-only.
    "kernel.dmesg_restrict" = 1;

    # Block following symlinks/hardlinks in world-writable dirs unless owner
    # matches — kills classic /tmp races.
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    # Ignore broadcast ICMP echo (no smurf amplification).
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Drop source-routed and redirected packets.
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Log martians for forensic value (low volume on these hosts).
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # Reverse-path filter — drops spoofed source IPs at the interface.
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
  };

  # Per-service systemd hardening for weechat / restic / subportal-agent
  # lives in the machine configs (machines/{chat,web2}/configuration.nix) —
  # those services don't run on every host so the overrides are scoped there.
}
