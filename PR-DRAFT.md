## Notes
* I am working off a nixpkgs-22.05, so may need some porting onto master
* I am attempting two things (in sequence) related to building `vm` and `vmWithBootLoader`:
    * (Mostly done, just needs cleaning up and PR-ing (rebase onto master also)) sharing the host's store:
        * `vm` shares the host store fine, but `vmWithBootLoader` does not, due to the implementation going via the qemu-provided kernel parameters. It doesn't even register the current closure in the nix db. Thus when doing a deployment (e.g. testing a deploy-rs config) with a minor change on the vm, we need to copy the whole running system!
        * This means that interation is very slow!
        * I may want to make it configurable on/off? This would make it easy to see what needs copying if doing a dry run of an actual remote.
		  EDIT: not so sure about this now -- the only things registered are the closure of the system, so still copy differences (even though they exist in the store directory, they are not registered in the db, so will be copied)
        * I have looked into this before https://github.com/NixOS/nixpkgs/issues/128216, trying to integrate with the current implementation, but it seems tricky (I should revisit -- I don't know why using `postBootCommands` directly was too early (before devices mount), but `sed`ing the bootloader entry (which is then referenced in `postBootCommands`) apparently worked.
        * I wonder if adding an appropriate `systemd` unit would be the best way to go?
		* I am trying to add a nixos test to ensure it works
		  * I would like to test `nix-store --gc --print-roots` does something sensible, like listing `/run/{current,booted}-system`, and that `nix-store --dump-db` is non-empty.
		* An aside: Can I make the drive layout into nix attributes (or similar), so can programmatically access, rather than hardcoding magic device names?
		  Background: changing to this branch of nixpkgs broke my try-a-deploy-on-a-temporary-vm, as it hardcoded `/dev/vdb2` as the boot drive, but it is now `/dev/vdc2`!
		  CF Question Q6 below
    * Making the VM rebootable in two senses:
        * in one qemu session doing `systemctl reboot`
        * exiting the qemu session and firing another up
		* These both assume that the store is writable
        * I want this so can easily test remote deployments on a vm
		
## Questions:

### Q1
https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests says

> Tests that are part of NixOS are added to nixos/tests/all-tests.nix.
> `hostname = runTest ./hostname.nix;`

but that file seems to mostly use `handleTest`.
Which to use? Should something be updated?

### Q2
Is there any automatic discovery / a test that every test fixture is used?

### Q3 Documentation inconsistencies
`man nixos-rebuild` says that both flavors of vm share the host store readonly.
However, in reality they both have a writable overlayfs store, and only `vm` properly registers store contents
/nixpkgs/nixos/modules/virtualisation/qemu-vm.nix says similar.


https://nixos.org/manual/nixos/stable/index.html#sec-nixos-test-nodes says
>  `virtualisation.writableStore`
>    By default, the Nix store in the VM is not writable.
However, it is!
/nixpkgs/nixos/modules/virtualisation/qemu-vm.nix has
> virtualisation.writableStore =
>       mkOption {
>         type = types.bool;
>         default = true; # FIXME
>         ...
See commit a02bb00156086b45e68c1112008db506734f8649

### Q4 testing
https://nixos.org/manual/nixos/stable/index.html#ssec-machine-objects
says `screenshot` "takes a picture...is linked from the HTML log."
I see the screenshots in `./result`, but what/where is this HTML log?

### Q5 feedback
I have added a bunch of tests of store-sharing.
I'm not sure if they are all useful to have, or some are redundent etc

### Q6 changing drive names
(cf my aside about breaking try-a-deploy-on-a-temporary-vm because of hardcoded device names)
This changes device names.
The root device stays the same, but everything else moves.
This was done out of expediency, since it gave a stable name to the regInfo drive and I updated references to boot drive in nixpkgs.
However, I don't know how many configs in the wild may hardcode `/boot = /dev/vdb2` and would be broken.
Two thoughts:
- I could just put the reginfo drive at the end
- potentially we should expose an attrset of drive names?
