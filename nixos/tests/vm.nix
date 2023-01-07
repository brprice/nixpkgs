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

  tmpInternalReboot = makeTest {
    # NB: this test does not work at all
    # - with vanilla nixpkgs, the test runner passes '-no-reboot' to qemu, thus killing the vm when it wants to reboot
    # - with a one word change to 'machine.py' to set 'allow_reboot = True', we cause a massive rebuild and the initial wait_for_unit("multi-user.target") never completes
    # - with also changing the qemu_opts to keep the device options, the vm runs and reboots, but the test driver errors out with `error: "invalid literal for int() with base 10: ''"` at roughly the point where in the first boot it connected to the guest root shell. I see no obvious differences in the log.
    #   See previous commit's message for some clues
    #   It appears that --no-reboot was first added in b1aa227cbdca8c7c17e622c8cdf89949e06e66f4 (in 2009!) to avoid qemu going into an infinite loop with a panic-ing kernel
    #   Can I test/demonstrate this problem? (How to synthetically cause a kernel panic?)
    #   Perhaps these days we can use the '-action' mechanism in qemu to allow reboots but halt on a panic
    #   See https://www.qemu.org/docs/master/interop/qemu-qmp-ref.html#qapidoc-141
    #   (however, this is beside the point for this crash - it seems that some invariant in the test driver is broken, causing it to confuse command output and command exit code (seemingly it hasn't realised that an extra line has snuck in (or out?), causing output to happen when a return code is expected and vice versa))
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
           machine.execute("reboot")
           machine.wait_for_unit("multi-user.target")
           machine.succeed("ls /test")
  '';
  };
}
