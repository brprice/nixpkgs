### HMM, I wanted to make a nixos test for vm store sharing, but don't
# think I can do it -- cannot seem to do a test of vmWithBootLoader
#
# Maybe I need to look at ~/dev/nixpkgs/nixos/tests/systemd-boot.nix

import ./make-test-python.nix ({ pkgs, latestKernel ? false, ... }:

{
  name = "vm";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ brprice ];
  };

  nodes.machine =
    { pkgs, lib, ... }:
    { boot.kernelPackages = lib.mkIf latestKernel pkgs.linuxPackages_latest;
      boot.loader.systemd-boot.enable = true; # DOES NOT DO WHAT I WANT...
      virtualisation.useBootLoader = true;
    };

  testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_until_succeeds("pgrep -f 'agetty.*tty1'")
      machine.screenshot("postboot")

      with subtest("create user"):
          machine.succeed("useradd -m alice")
          machine.succeed("(echo foobar; echo foobar) | passwd alice")

      with subtest("Check whether switching VTs works"):
          machine.fail("pgrep -f 'agetty.*tty2'")
          machine.send_key("alt-f2")
          machine.wait_until_succeeds("[ $(fgconsole) = 2 ]")
          machine.wait_for_unit("getty@tty2.service")
          machine.wait_until_succeeds("pgrep -f 'agetty.*tty2'")

      with subtest("Log in as alice on a virtual console"):
          machine.wait_until_tty_matches(2, "login: ")
          machine.send_chars("alice\n")
          machine.wait_until_tty_matches(2, "login: alice")
          machine.wait_until_succeeds("pgrep login")
          machine.wait_until_tty_matches(2, "Password: ")
          machine.send_chars("foobar\n")
          machine.wait_until_succeeds("pgrep -u alice bash")
          machine.send_chars("touch done\n")
          machine.wait_for_file("/home/alice/done")

      machine.succeed("false")

      with subtest("Virtual console logout"):
          machine.send_chars("exit\n")
          machine.wait_until_fails("pgrep -u alice bash")
          machine.screenshot("getty")

      with subtest("Check whether ctrl-alt-delete works"):
          machine.send_key("ctrl-alt-delete")
          machine.wait_for_shutdown()
  '';
})
