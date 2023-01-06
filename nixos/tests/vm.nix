### HMM, I wanted to make a nixos test for vm store sharing, but don't
# think I can do it -- cannot seem to do a test of vmWithBootLoader
#
# Maybe I need to look at ~/dev/nixpkgs/nixos/tests/systemd-boot.nix
{ system, pkgs }:

with import ../lib/testing-python.nix { inherit system pkgs; };
let testStoreSharing = { useBootLoader, initrdSystemd }: makeTest  {
  name = "vm";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ brprice ];
  };

  nodes.machine =
    { pkgs, lib, ... }:
    {
      imports = [ ../modules/virtualisation/qemu-vm.nix ];
      virtualisation.useBootLoader = useBootLoader;
      boot.initrd.systemd.enable = initrdSystemd;
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
  noBootLoader = testStoreSharing {useBootLoader = false; initrdSystemd = false;};
  withBootLoader = testStoreSharing {useBootLoader = true; initrdSystemd = false;};
  noBootLoaderInitrdSystemd = testStoreSharing {useBootLoader = false; initrdSystemd = true;};
  withBootLoaderInitrdSystemd = testStoreSharing {useBootLoader = true; initrdSystemd = true;};

  tmpExternalReboot = makeTest {
    name = "tmp";
    meta = with pkgs.lib.maintainers; {
      maintainers = [ brprice ];
    };
    nodes.machine =
      { pkgs, lib, ... }:
      {
        imports = [ ../modules/virtualisation/qemu-vm.nix ];
        virtualisation.useBootLoader = false;
      };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.fail("ls /test")
      machine.succeed("touch /test")
      machine.succeed("ls /test")

      with subtest("rebooting persists data"):
           machine.shutdown()
           machine.wait_for_unit("multi-user.target")
           machine.succeed("ls /test")
  '';
  };
}
