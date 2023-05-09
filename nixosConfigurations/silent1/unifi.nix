{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  services.unifi = {
    enable = true;
    initialJavaHeapSize = 1024;
    jrePackage = pkgs.jre_headless;
    openFirewall = true;
    unifiPackage = pkgs.unifiStable;
  };

  services.nginx.virtualHosts."unifi.ztm.io" = {
    forceSSL = true;
    useACMEHost = "wild-ztm";

    locations."/" = {
      proxyPass = "https://localhost:8443";
    };
  };
}
