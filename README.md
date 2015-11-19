alphaos
=======

###Lightweight, portable and flexible operating system

alphaOS is a simple and minimalistic Linux distribution for the x86-64 architecture, built using Linux Live Kit set of scripts developed by Tomas M. It is based on Arch Linux and uses pacman as the default package manager. This operating system features highly configurable and lightweight Openbox window manager. Modular by design, alphaOS makes it easy to add desired functionality. 

This repository contains all bash scripts used for making alphaOS Linux based live CDs, and also set of several home-grown applications written in Vala and GTK+3: Emendo - text editor with syntax highlighting, Simple Radio - play online radio stations from the system tray, Taeni - terminal emulator, and others located in the def-scripts/03_extra directory.

[Home page](http://alphaos.tuxfamily.org/)

[Download from sourceforge](http://sourceforge.net/projects/alphaos/files/)

[How to: make alphaos from scratch](http://alphaos.tuxfamily.org/forum/viewtopic.php?f=14&t=1099)

how to: make alphaos from scratch
Postby simargl » 10 May 2014, 11:41

You can build alphaos system with help of this guide on any recent 64-bit Linux operating system (not on 32-bit because chroot will not work). It is required to use linux partition with at least 5 GB of free space mounted on /mnt/home. Tools needed to start are available in packages 'git' and 'make'. So, activate devel bundle or install packages with:
CODE: SELECT ALL
pacman -S git make

=========
Phase 1
Main system files in alphaOS are two system bundles/modules - alpha.sb and extra.sb. Those modules are built automatically from spkg packages, which are compiled inside chroot or converted from Arch packages. So, before making system modules first step is to prepare needed packages. 

1.1.)
First clone alphaos repository, you need to have git installed:
CODE: SELECT ALL
git clone https://github.com/alphaos/build

In alphaos/spkg/data/main.config you would change variables arm_date and CARCH (these variables define names of spkg packages, used CFLAGS when compiling and date for rollback mirror for Arch packages used by script paka), or you can just proceed with default values, and then install spkg package manager with:
CODE: SELECT ALL
make install


1.2.)
All packages are divided into 4 groups: 01_core, 02_xorg, 03_extra, 04_devel - first group with added rootfs from alphaos directory will make alpha.sb, 2nd and 3rd groups are later compressed as extra.sb. Before you start converting Arch packages first you need to prepare directories:
CODE: SELECT ALL
mkdir -p /mnt/home/data/alphaos/00_linux/spkg
mkdir -p /mnt/home/data/alphaos/01_core/arch
mkdir -p /mnt/home/data/alphaos/01_core/spkg
mkdir -p /mnt/home/data/alphaos/02_xorg/arch
mkdir -p /mnt/home/data/alphaos/02_xorg/spkg
mkdir -p /mnt/home/data/alphaos/03_extra/arch
mkdir -p /mnt/home/data/alphaos/03_extra/spkg
mkdir -p /mnt/home/data/alphaos/04_devel/arch
mkdir -p /mnt/home/data/alphaos/04_devel/spkg

Then sync paka's repository base, so you get list of available Arch packages in /var/lib/paka (community.list, core.list, extra.list), this uses packages from Arch Rollback Machine.
CODE: SELECT ALL
paka -Sy


1.3.)
Now you can start process of converting Arch Linux packages to spkg packages. In previously cloned bitbucket repository you will see directory alphaos/scripts/packages.list, change to that directory and start converting packages from the base group with:
CODE: SELECT ALL
for i in $(cat 01_core.list); do paka -Sd $i;done

After this completes, in /mnt/home/data/spkg you'll have two directories named packages and sources, now move those two directories to /mnt/home/data/alphaos/01_core/arch. Repeat this procedure for packages from other groups: 02_xorg.list, 03_extra.list, 04_devel.list and move converted packages and their sources to corresponding directories: 02_xorg, 03_extra, 04_devel in /mnt/home/data/alphaos.

Note:
Package linux-api-headers from Arch is needed just temporary, because spkg package with same name cannot be compiled if original linux-api-headers is not present. So, search for this package with:
CODE: SELECT ALL
paka -Ss linux-api-headers

and convert (currently this is the package name):
CODE: SELECT ALL
paka -Sd linux-api-headers-3.10.6-1-x86_64.pkg.tar.xz

Just temporary place converted package to /mnt/home/data/alphaos/04_devel/arch/packages. Later when linux-api-headers spkg package is compiled inside chroot, you will remove this Arch package.

1.4.)
Before moving to second phase you will need to compile filesystem package. Copy alphaos/def-scripts/01_core/filesystem to /mnt/home/data/spkg/def-scripts, open terminal and type:
CODE: SELECT ALL
spkg -c filesystem

Copy resulting package to /mnt/home/data/alphaos/01_core/spkg/packages, then move to 2nd phase.

=========
Phase 2
Now you need to setup build chroot and compile required spkg packages there, so they cannot interfere with the host system. To do that change to alphaos/scripts and type:
CODE: SELECT ALL
sh chroot_build min

2.1.)
Minimal chroot will contain packages from three groups: 00_linux, 01_core and 04_devel, and it will be made in /mnt/home/data/spkg/packages/install. Now copy spkg directory to chroot because it is needed to install spkg package manager inside chroot before you could start compiling. As before install it with: 
CODE: SELECT ALL
make install


2.2.)
Now change to alphaos/def-scripts and copy all directories from 00_linux, 01_core and 04_devel to /mnt/home/data/spkg/def-scripts inside chroot. This folder should be there, already created by chroot_build script. Now everything is done inside chroot. 
Connect to the internet,
CODE: SELECT ALL
dhcpcd

Start compiling packages from 04_devel group
CODE: SELECT ALL
spkg -c linux-api-headers


After it compiles you can remove, original Arch linux-api-headers package; change to /mnt/home/data/spkg/packages and type
CODE: SELECT ALL
spkg -r linux-api-headers
spkg -i linux-api-headers*

Then, you can start compiling linux kernel package:
CODE: SELECT ALL
spkg -c linux

..and packages from the 01_core group.

2.3.)
Now you can move compiled packages to previously prepared folders: 01_core group to /mnt/home/data/alphaos/01_core/spkg/packages, 00_linux group that has just linux package to /mnt/home/data/alphaos/00_linux/spkg/packages and 04_devel to /mnt/home/data/alphaos/04_devel/spkg/packages. Don't forget to save boot-${version}.tar.xz and linux_${version}_src.sb, files produced after kernel compiling, you move them to /mnt/home/data/alphaos/00_linux/spkg/other. Now, remove linux-api-headers converted Arch package from /mnt/home/data/alphaos/04_devel/arch/packages.

2.4.)
Now you need to repeat this step with making chroot to compile packages from other two groups: 02_xorg and 03_extra. Change to alphaos/scripts, but this time type:
CODE: SELECT ALL
sh chroot_build full

After compiling move packages to their respective folders as explained above. Now you can move on to next phase.

=========
Phase 3
Extract /mnt/home/data/alphaos/00_linux/spkg/other/boot-${version}.tar.xz and copy vmlinuz to /mnt/home/alphaos/boot

Change to alphaos/scripts and make initrd.gz with:
CODE: SELECT ALL
sh newinit

copy initrfs.img to /mnt/home/alphaos/boot

Now make two main system sb modules (in alphaos/scripts/functions you can set gzip or xz compression):
CODE: SELECT ALL
sh sb_build base

copy alpha.sb to /mnt/home/alphaos

CODE: SELECT ALL
sh sb_build extra

copy extra.sb to /mnt/home/alphaos

After that you can create iso images:
CODE: SELECT ALL
sh makeiso -s

for standard desktop iso.

CODE: SELECT ALL
sh makeiso -m

for minimal console-only iso, containing just alpha.sb (01_core group only)

If you have any issue with following this tutorial report it here
