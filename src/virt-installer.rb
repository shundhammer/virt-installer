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
    attr_accessor :dir, :name, :size, :force_root_dir, :must_exist

    def initialize
      @dir  = "/space/libvirt/images"
      @name = "test.qcow2"
      @size = "40G"
      @created        = false
      @must_exist     = false
      @force_root_dir = false
    end

    def path
      "#{@dir}/#{@name}"
    end

    def create
      raise "Virtual disk #{path} must exist" if @must_exist
      if File.dirname(path) == "/" && !@force_root_dir
        raise "Refusing to create disk image in root directory: #{path}"
      end
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

    def must_exist?
      @must_exist
    end
  end

  attr_accessor :iso_dir, :disk, :disk2, :name, :mem, :iso
  attr_accessor :use_ssh, :ssh_password
  attr_accessor :use_vnc, :vnc_password
  attr_accessor :use_serial_console
  attr_accessor :use_uefi, :use_multipath
  attr_accessor :boot_insecure
  attr_accessor :self_update
  attr_accessor :debug, :dry_run

  def initialize
    @iso_dir            = "/space/iso"
    @name               = "Test-VM"
    @mem                = 2048 # MB
    @use_ssh            = true
    @ssh_password       = nil
    @use_vnc            = false
    @vnc_password       = nil
    @use_uefi           = false
    @use_multipath      = false
    @use_serial_console = false
    @boot_insecure      = false
    @self_update        = false
                        
    @iso                = nil
    @debug              = false
    @dry_run            = false
                        
    @disk               = VirtualDisk.new
    @disk2              = nil
    @multipath_no       = "00"
    ENV["lang"]         = "C" # avoid translated output from external commands
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

  def ovmf_installed?
    !Dir.glob(OVMF_DIR + "/ovmf-*.bin").empty?
  end

  def disk_args(disk)
    return "" if disk.nil?
    if @use_multipath
      args = "--disk #{disk.path},serial=multipath_test_#{@multipath_no.succ!}"
      args += " " + args
    else
      args = "--disk #{disk.path}"
    end
    args
  end

  def uefi_args
    return "" unless @use_uefi
    raise "Package qemu-ovmf-x86_64 not installed!" unless ovmf_installed?

    args = []
    args << "loader=#{OVMF_DIR}/ovmf-x86_64-code.bin"
    args << "loader_ro=yes"
    args << "loader_type=pflash"
    args << "nvram_template=#{OVMF_DIR}/ovmf-x86_64-vars.bin"

    "--boot " + args.join(",")
  end

  def ssh_args
    return nil unless @use_ssh
    args = "ssh=1"
    args += " sshpassword=#{ssh_password}" if @ssh_password
    args += " startshell=1"
    args
  end

  def serial_console_args
    return nil unless @use_serial_console
    
    "console=ttyS0,57600"
  end

  def kernel_args
    args = []
    args << ssh_args
    args << "insecure=1" if @boot_insecure
    args << "self_update=0" unless @self_update
    args << serial_console_args
    args.compact!
    return "" if args.empty?

    extra_args = args.join(" ")
    "--extra-args \"#{extra_args}\""
  end

  def vnc_args
    return "" unless @use_vnc
    raise "vnc_password not set" unless @vnc_password
    "--graphics vnc,password=#{@vnc_password}"
  end

  def start
    raise "Insufficient permissions - run this with 'sudo'!" unless root_permissions?

    kill if running?
    delete if exist?

    @disk.create  unless @disk.exist?
    @disk2.create unless @disk2.nil? || @disk2.exist?
    find_iso("*") if @iso.empty?
    print "Using ISO #{@iso}\n"

    if @use_ssh && @use_vnc
      @use_ssh = false
      print "Can't use both ssh and VNC together - disabling ssh\n"
    end

    cmd = "virt-install"
    args = []
    args << "--connect=qemu:///system"
    args << "--location=#{@iso}"
    args << "--name=#{@name}"
    args << disk_args(@disk)
    args << disk_args(@disk2)
    args << "--memory=#{@mem}"
    args << uefi_args if @use_uefi
    args << kernel_args
    args << vnc_args  if @use_vnc
    args << "|& egrep -v '(WARNING|ERROR|CRITICAL) \*\*'" # Get rid of brain-dead Gtk bullshit messages

    cmd += " " + args.join(" ")

    print "\n\n*** DRY RUN - not executing ***\n" if @dry_run
    print "\n#{cmd}\n\n"
    system(cmd) unless @dry_run
  end
end

if $PROGRAM_NAME == __FILE__  # Called direcly as standalone command?

  # Common for most use cases
  vm = VirtInstaller.new
  vm.name      = "SLES-12-Test-VM"
  vm.disk.name = "sles-test-disk.qcow2"
  vm.disk.size = "40G"
  vm.find_iso("SLE-12*")

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
