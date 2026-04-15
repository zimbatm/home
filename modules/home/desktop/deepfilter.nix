{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.home.deepfilter = {
    enable = lib.mkEnableOption "DeepFilterNet noise cancellation via PipeWire LADSPA";
    attenuation = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Attenuation limit in dB. Higher = more aggressive noise removal.";
    };
  };

  config = lib.mkIf config.home.deepfilter.enable {
    xdg.configFile."pipewire/pipewire.conf.d/99-deepfilter.conf".text = builtins.toJSON {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "DeepFilter Noise Canceling Source";
            "media.name" = "DeepFilter Noise Canceling Source";
            "filter.graph" = {
              nodes = [
                {
                  type = "ladspa";
                  name = "DeepFilter Mono";
                  plugin = "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so";
                  label = "deep_filter_mono";
                  control = {
                    "Attenuation Limit (dB)" = config.home.deepfilter.attenuation;
                  };
                }
              ];
            };
            "audio.rate" = 48000;
            "audio.position" = "[MONO]";
            "capture.props" = {
              "node.passive" = true;
            };
            "playback.props" = {
              "media.class" = "Audio/Source";
            };
          };
        }
      ];
    };
  };
}
