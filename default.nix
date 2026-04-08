# Non-flake entrypoint — reads flake.lock, lets iets eval without builtins.getFlake.
# The shim is vendored from kin/lib/flake-shim.nix until iets has native flakes (B3).
import ./flake-shim.nix ./.
