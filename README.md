virt-installer
==============

Ruby class to simplify virtual installations with QEMU/libvirt/virt-installer.

Author: Stefan Hundhammer <shundhammer@suse.de>

This might be useful for others who need to develop and debug in the inst-sys,
no matter if you are a YaST, linuxrc or maybe kernel developer or if you are
just making installation ISOs for whatever reason: You have an installation ISO
image, and you need to test that installation. Support ssh installation, for
multipath, for UEFI is built in.

This started as bash scripts that saw too much copy & paste, so I finally
decided to port it to Ruby so I could use a common base class and just modify
some parameters.

In my personal work environment, I can use the scripts in the examples/
subdirectory directly. Others will have to modify the paths there. The examples
should be pretty much self-explanatory.

The examples all use vm.find_iso() which will pick the latest ISO matching the
supplied (file glob) pattern in the ISO directory, but the ISO can be simply
set as well with

    vm.iso = "/path/to/my.iso"

The other settings like vm.name, vm.disk.name etc. serve mostly to keep various
virtual machines apart so you can easily restart them with "virt-manager". If
you don't like that, you might as well leave them out and keep the default
values.

In general, for most settings there is a reasonable default you can use.

On the other hand, all low-level methods are exported, so you can use them in
your custom scripts - e.g. check if the VM is running or if it exists or kill
it or delete it completely with

    vm.running?
    vm.exist?
    vm.kill
    vm.delete

(intentionally using the slightly broken Ruby way of ignoring correct English
grammar to retain consistency with other Ruby classes).

This is work in progress and will likely see improvements over time.

There is no RPM, Spec-file, complex build system, nor are there unit tests so
far; this is being tested as I use it to do my daily work.


USAGE
=====

Call one of the examples with 'sudo':

    sudo virt-install-sles

Then, in another terminal window, ssh to that machine and start the
installation there:

    ssh -X root@...
    yast.ssh

When the installation is done, you will have to quit that ssh session and
typically also in the console of that machine the shell running there (which is
a safeguard against an installer crash so y2logs can still easily be salvaged).


EXAMPLE
=======

    #!/usr/bin/ruby

    require_relative "./virt-installer"

    vm = VirtInstaller.new
    # Personal work environment
    vm.disk.dir      = "/space/libvirt/images"
    vm.iso_dir       = "/space/iso"

    # VM-specific settings
    vm.name          = "SLES-12-Test-VM"
    vm.disk.name     = "sles-test-disk.qcow2"
    vm.disk.size     = "40G"
    vm.find_iso("SLE-12-SP1*") # Use the last matching one

    # Detail flags - not strictly neccessary, might as well use defaults
    vm.use_ssh       = true
    vm.ssh_password  = "root"  # linuxrc will ask if not set (nil)
    vm.use_multipath = false
    vm.use_uefi      = false
    # vm.use_vnc       = true
    # vm.vnc_password  = "vnc"   # must specify password if use_vnc

    # Uncomment to test invocation
    # vm.dry_run = true

    vm.start



INSTALLATION
============

Symlink the .rb file to your ~/bin/ directory, copy the examples you like to
the same directory and edit the paths as needed.

So far, I intentionally decided against using a config file to keep things
simple: The examples are short and simple enough to be edited in place.


DISCLAIMER
==========

Use at your own risk. There be dragons etc.; you know the drill. ;-)

Under no circumstances will I or my company be held responsible for anything
that happens when you use this software.

[insert legal blurb of choice here - MENTALLY, not literally]
