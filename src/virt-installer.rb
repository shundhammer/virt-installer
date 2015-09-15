#!/usr/bin/ruby
#
# License: GPL 2 (see file COPYING for details)
#
# (c) 2015 SUSE LLC
#

require "pp"

# Class to handle VM installations via libvirt/virt-install.
class VirtInstaller
  OVMF_DIR = "/usr/share/qemu"

  # Class that represents a virtual disk
  class VirtualDisk
    attr_accessor :name, :size

    def initialize
      @name = "test.qcow2"
      @size = "40G"
      @created = false
    end

    def path
      "#{@storage_dir}/#{@name}"
    end

    def create
      cmd = "qemu-img create -f qcow2 #{path} #{size}"
      print "Creating virtual disk:\n#{cmd}\n" if @debug
      system cmd
      @created = true
    end

    def created?
      @created
    end

    def exist?
      File.exist?(path)
    end
  end

  attr_accessor :storage_dir, :iso_dir, :disk
  attr_accessor :name, :mem, :iso, :use_ssh
  attr_accessor :use_uefi, :use_multipath
  attr_accessor :debug, :dry_run

  def initialize
    @storage_dir   = "/space/libvirt/images"
    @iso_dir       = "/space/iso"
    @name          = "Test-VM"
    @mem           = 2048 # MB
    @use_ssh       = true
    @use_uefi      = false
    @use_multipath = false

    @iso           = nil
    @debug         = false
    @dry_run       = false

    @disk          = VirtualDisk.new
    ENV["lang"]    = "C" # avoid translated output from external commands
  end

  def run_cmd(cmd)
    print "Executing:\n#{cmd}\n" if @debug
    output = `#{cmd}`
    output.split("\n")
  end

  def running?
    run_cmd("virsh list --name").include? @name
  end

  def exist?
    run_cmd("virsh list --name --all").include? @name
  end

  def kill
    run_cmd("virsh destroy #{@name}")
  end

  def delete
    run_cmd("virsh undefine #{@name}")
  end

  def find_iso(pattern)
    files = Dir.glob(@iso_dir + "/" + pattern + ".iso").sort
    # print "Matching ISOs: \n#{pp files}" if @debug
    raise "No ISO matching #{pattern} in #{@iso_dir}" if files.empty?
    @iso = files.last
  end

  def root_permissions?
    Process::UID.eid == 0
  end

  def omvf_installed?
    !Dir.glob(OVMF_DIR + "/ovmf-*.bin").empty?
  end

  def disk_args
    if @use_multipath
      args = "--disk #{@disk.path},serial=multipath_test_01"
      args += " " + args
    else
      args = "--disk #{@disk.path}"
    end
    args
  end

  def uefi_args
    return "" unless @use_uefi
    raise "Package qemu-ovmf-x86_64 not installed!" unless omvf_installed?

    args = []
    args << "loader=#{OVMF_DIR}/ovmf-x86_64-opensuse-code.bin"
    args << "loader_ro=yes"
    args << "loader_type=pflash"
    args << "nvram_template=#{OVMF_DIR}/ovmf-x86_64-opensuse-vars.bin"

    "--boot " + args.join(",")
  end

  def ssh_args
    @use_ssh ? "--extra-args \"ssh=1\"" : ""
  end

  def start
    raise "Insufficient permissions - run this with 'sudo'!" unless root_permissions?

    kill if running?
    delete if exist?

    @disk.create unless @disk.exist?
    find_iso("*") if @iso.empty?
    print "Using ISO #{@iso}\n"

    cmd = "virt-install"
    args = []
    args << "--connect=qemu:///system"
    args << "--location=#{@iso}"
    args << "--name=#{@name}"
    args << disk_args
    args << "--memory=#{@mem}"
    args << uefi_args if @use_uefi
    args << ssh_args  if @use_ssh

    cmd += " " + args.join(" ")

    print "\n\n*** DRY RUN - not executing ***\n" if @dry_run
    print "\n#{cmd}\n\n"
    system(cmd) unless @dry_run
  end
end

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command?

  # Common for most use cases
  vm = VirtInstaller.new
  vm.name = "SLES-12-Test-VM"
  vm.disk.name = "sles-test-disk.qcow2"
  vm.disk.size = "40G"
  vm.find_iso("SLE-12-SP1*")

  # Debug options - only if desired
  # vm.debug = true
  vm.dry_run = true

  # Just testing some of the features
  print "VM exists\n"  if vm.exist?
  print "VM running\n" if vm.running?
  # print "qemu_ovmf_x86_64 not installed!\n" unless vm.omvf_installed?

  # Actually start the VM
  vm.start
end
