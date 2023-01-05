### HMM, I wanted to make a nixos test for vm store sharing, but don't
# think I can do it -- cannot seem to do a test of vmWithBootLoader
#
# Maybe I need to look at ~/dev/nixpkgs/nixos/tests/systemd-boot.nix
{ system, pkgs }:

with import ../lib/testing-python.nix { inherit system pkgs; };
let testStoreSharing = { useBootLoader }: makeTest  {
  name = "vm";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ brprice ];
  };

  nodes.machine =
    { pkgs, lib, ... }:
    {
      imports = [ ../modules/virtualisation/qemu-vm.nix ];
      virtualisation.useBootLoader = useBootLoader;
    };

  testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("current-system roots"):
          machine.succeed("nix-store --query /run/current-system --roots | grep -q -F '/run/current-system'")

      with subtest("all roots"):
          machine.succeed("test $(nix-store --gc --print-roots | wc -l) -ge 1")

      with subtest("dump db"):
          machine.succeed("test $(nix-store --dump-db | wc -l) -ge 1")
  '';
};
in 
{
  noBootLoader = testStoreSharing {useBootLoader = false;};
  withBootLoader = testStoreSharing {useBootLoader = true;};
}
