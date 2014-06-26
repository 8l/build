#!/usr/bin/bash

# -------------------------------
# ----------- License -----------
# -------------------------------
# @licstart
# Copyright (C) 2014  Free Software Foundation, Inc
# 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You may have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# @licend
# -------------------------------
# ----------- License -----------
# -------------------------------

# -------------------------------
# ------------ TODO -------------
# -------------------------------
# - create drop-down field (yad --text-info --tail --listen) showing console output (`script`)
# - uuidgen for sgdisk? so one is certain about the UUID the newly created partition has been assigned
# - make partition selection dialog only contain partitions of selected disk
#   must be dynamic. ie. when one changes install disk choice, available partitions must be updated
#     compatible with loop devs?
# - validate more shizz
# - maybe make it more suited to install to UEFI without cleaning disk
# - maybe research more modules for GRUB. for instance, peek at Arch grub-mkconfig ones.
# - maybe move to UUIDs?
# - would be nice to migrate yad lists to --list. but it seems yad supports opnly one list per dialog.
# - aesthetics :)
# -------------------------------
# ------------ TODO -------------
# -------------------------------

# -------------------------------
# ------------ Init ------------- 
# -------------------------------
# read local functions
. /etc/rc.d/functions
. /etc/os-release
# -------------------------------
# ------------ Init ------------- 
# -------------------------------

# -------------------------------
# ---------- Variables ----------
# -------------------------------
version='0.05'
# format: 'package:file-to-test-for another-package:file-tested-with-which-command'
dependencies='grub:grub-install gptfdisk:sgdisk dosfstools:mkfs.fat'

installDisk=''
rootMount='/mnt/inst'
rootPart=''
alphaOSDir=''
alphaOSInstPath=''
biosPart=''
ESPMount='/mnt/boot/efi'
ESP=''
grubcfgfile="${rootMount}/boot/grub/grub.cfg"

alphaOSDir='/alphaos'
alphaOSSrcDir='/mnt/live/memory/data/alphaos'
if [ ! -d "${alphaOSSrcDir}" ]; then
    alphaOSSrcDir='/mnt/home/alphaos'
fi
# 4 required files, and empty modules dir
alphaOSFiles=("/alpha_${VERSION}.sb" "/extra_${VERSION}.sb" '/boot/initrfs.img' '/boot/vmlinuz' '/modules/')

# dialog
dialog="$(which yad)"
# YAD
dtitle='--title=alphainst.sh'
# need to run fixed, as YAD behaves weirdly, adding lots of newlines.
dsettings='--center --fixed --borders=8 --always-print-result --selectable-labels --window-icon=drive-harddisk-system'
dialog="${dialog} ${dtitle} ${dsettings}"
dyescode=90
dyes="--button=Yes:${dyescode}"
dnocode=91
dno="--button=No:${dnocode}"
dokcode=92
dok="--button=OK:${dokcode}"
dhomecode=98
dhome="--button=Home:${dhomecode}"
dquitcode=99
dquit="--button=Close:${dquitcode}"
# -------------------------------
# ---------- Variables ----------
# -------------------------------

# -------------------------------
# ---------- Functions ----------
# -------------------------------

privcheck () {
if (( ${EUID} != 0 )); then
   echo -e ${BRed}"==> "${BWhite}"This script must be run as root. Type in 'su -c ${0}' to run it as root."
   if [ -n "${dialog}" ]; then
      ${dialog} ${dok} --text="This script must be run as root.\nType 'su -c ${0}' in a terminal to run it as root."
   fi
   exit 1
fi
}

escapeforsed () {
#~ # sed it like a boss \/
#~ echo $(echo ${1} | sed -e 's/\//\\\\\//g')
# sed it like a pro -.- ~https://stackoverflow.com/questions/407523/escape-a-string-for-a-sed-replace-pattern
echo $(echo ${1} | sed -e 's/[\/&]/\\&/g')
}

depensure () {
echo -e ${BGreen}"==> "${BWhite}"checking dependencies"${Color_Off}

pkg=''
prog=''
pkgToInstall='BOGUS-START-VALUE'

# cannot proceed as long as dependencies are not met
while [ -n "${pkgToInstall}" ]; do
    # check if dependencies are met
    pkgToInstall=''
    for dep in ${dependencies}; do
        pkg=$(echo ${dep} | cut -d ':' -f 1)
        prog=$(echo ${dep} | cut -d ':' -f 2)
        
        which ${prog} > /dev/null
        if [ "${?}" = 1 ]; then
            pkgToInstall+=" ${pkg}"
        fi
    done
    
    # install if anything to install
    if [ -n "${pkgToInstall}" ]; then
      echo -e $BYellow"==> "${BWhite}"missing${pkgToInstall}"${Color_Off}
        # update pacman cache if we have to
        if [ ! -f /var/lib/pacman/sync/community.db ]; then
            pacman -Sy
        fi
        pacman -S ${pkgToInstall}
        
        # quit if user declined installation
        if [ ${?} == 1 ]; then
         echo -e $BRed"==> "${BWhite}"cannot run without all dependencies"${Color_Off}
         exit
      fi
    fi
done

echo -e ${BGreen}"==> "${BWhite}"all dependencies met"${Color_Off}
}

getdevpath () {
lsblk --noheadings --raw --paths --output NAME ${1}
}

getpartbypartlabel () {
# yeah, it's getting rough. please, enlighten me the right way to do stuff :D
lsblk --noheadings --raw --paths --output NAME,PARTLABEL | sed 's/\\x20/ /g' | grep "${1}" | cut -d ' ' -f 1
}

# $1 = sgdisk output
getpartnumfromsgdiskoutput () {
# process sgdisk output, looking for 'partNum is n', where we get n.
# sgdisk counts from 0, whereas Linux counts from 1
sgp=$(echo "${1}" | grep --ignore-case --only-matching --extended-regexp 'partNum is [0-9]+' | awk '{print $3}')
sgp=$(( ${sgp} + 1 ))
echo ${sgp}
}

# $1 = mount point
# $2 = partition path
mountpart () {
echo -e ${BWhite}"==> mounting ${1} on ${2}"${Color_Off}
mkdir -p ${2}
mount ${1} ${2}
}

unmountdir () {
sync
echo -e ${BWhite}"==> unmounting ${1}"${Color_Off}
umount ${1}
rmdir ${1}
}

# $1 = space separated dev list
# $2 = item to pre-select
processdevlistforyad () {
# get all devices, in format 'devpath (size)!devpath (size)!^prechosendevpath!et cetera'

devs="${1}"
devList=''

if [ -n "${devs}" ]; then
   for dev in ${devs}; do
      # add device and it's size
      # yad delimiter is "!"
      devList="${devList}!${dev} ($(lsblk --nodeps --noheadings --raw --output SIZE ${dev}))"
   done
   #~ # cut first (blank) entry
   #~ devList=$(echo ${devList} | cut -d '!' -f 2-)
   # mark pre-chosen disk, if exists
   if [ -n "${2}" ]; then
      devList=$(echo ${devList} | sed "s/\($(escapeforsed ${2})\)/\^\1/")
   fi
fi

echo ${devList}
}

getdisks () {
#~ devs=$(ls /dev/disk/by-uuid)
#~ devs=$(ls /dev/disk/by-id)
devs=$(lsblk --nodeps --noheadings --paths --raw --output NAME,TYPE | grep 'disk' | cut -d ' ' -f 1)

processdevlistforyad "${devs}" "${installDisk}"
}

getpartitions () {
devs=''

# if install disk is chosen, only get partitions of install disk
# else, get all partitions, and exclude ones with irrelevant type. (disk, etc.)
#   this lines up well in a one-liner, as ${installDisk} will be an empty string if not set
#~ devs=$(lsblk --noheadings --paths --raw --output NAME,TYPE ${installDisk} | grep -E -v 'disk|rom' | cut -d ' ' -f 1)
devs=$(lsblk --noheadings --paths --raw --output NAME,TYPE ${installDisk} | grep 'part' | cut -d ' ' -f 1)

processdevlistforyad "${devs}" "${rootPart}"
}

getESPs () {
# try and get all EF00 parititons
# is Linux supposed to be this hacky? 8D
disks=$(lsblk --nodeps --noheadings --paths --raw --output NAME,TYPE | grep 'disk' | cut -d ' ' -f 1)
esps=''

for disk in ${disks}; do
   for esp in $(sgdisk -p ${disk} | grep -i 'EF00' | awk '{print $1}'); do
      esps+="${disk}${esp}"
   done
done

processdevlistforyad "${esps}" "${ESP}"
}

installdiskcheck  () {
if [ -z "${installDisk}" ]; then
   ${dialog} --text="You have to choose an install disk first" ${dok}
   return 1
fi
}

installpartcheck () {
if [ -z "${rootPart}" ]; then
   ${dialog} --text="You have to choose a partition for the alphaOS system files first" ${dok}
   return 1
fi
}

uefipartcheck () {
if [ -z "${ESP}" ]; then
   ${dialog} --text="You have to choose an EFI System Partition for the UEFI files first" ${dok}
   return 1
fi
}

preparedisk () {
installdiskcheck || return

${dialog} --image="dialog-warning" ${dyes} ${dno} --text="Will now clean and format ${installDisk}\nALL DATA ON THIS DISK WILL BE ERASED!\nAre you sure you want to continue?"
if [ ${?} = ${dnocode} ]; then
   return
fi

# we use GPT. MBR belongs to the past.
# go for sgdisk
# ~ http://rodsbooks.com/gdisk/sgdisk-walkthrough.html
# clean disk
echo -e ${BGreen}"==> "${BWhite}"cleaning ${installDisk} using sgdisk"${Color_Off}
sgdisk --zap-all ${installDisk}

# create BIOS boot partition
${dialog} --image="dialog-question" ${dyes} ${dno} --text='Would you like to create a BIOS boot partition,\nto be able to boot from BIOS systems?'
if [ ${?} = ${dyescode} ]; then
   # 1007K value retrieved from Arch wiki
   biosPartSize='1007K'
   biosPartLabel='BIOS boot partition'
   
   echo -e ${BGreen}"==> "${BWhite}"creating ${biosPartSize} BIOS boot partition on ${installDisk}"${Color_Off}
   
   # capture stdout, to get the partNum of the created partition
   # create a fd, which just redirects to stdout
   exec 5>&1
   sgdiskOut=$(sgdisk --new=0:0:+${biosPartSize} --change-name=0:"${biosPartLabel}" --typecode=0:ef02 ${installDisk} | tee >(cat - >&5))
   exec 5>&-
   
   # record BIOS boot partition
   # is it always analogous to ${installDisk}(${partNum}+1)?
   biosPart=${installDisk}$(getpartnumfromsgdiskoutput "${sgdiskOut}")
   #~ biosPart=$(getpartbypartlabel "${biosPartLabel}")
   
   sync
fi

# create EFI System Partition
${dialog} --image="dialog-question" ${dyes} ${dno} --text='Would you like to create an EFI System Partition,
to be able to boot from UEFI systems?

note: UEFI Secure Boot is not supported by alphainst.sh as of today.'
if [ ${?} = ${dyescode} ]; then
   ESPLabel='EFI System Partition'
   # recommended size is 512M, but how low can we go?
   #~ efiPartSize='512M'
   # 32MB is minimum size for FAT, go just above
   efiPartSize='33M'
   
   echo -e ${BGreen}"==> "${BWhite}"creating ${efiPartSize} EFI System Partition on ${installDisk}"${Color_Off}
   
   exec 5>&1
   sgdiskOut=$(sgdisk --new=0:0:+${efiPartSize} --change-name=0:"${ESPLabel}" --typecode=0:ef00 ${installDisk} | tee >(cat - >&5))
   exec 5<&-
   
   ESP=${installDisk}$(getpartnumfromsgdiskoutput "${sgdiskOut}")
   
   sync
   
   echo -e ${BGreen}"==> "${BWhite}"formatting EFI System Partition (${ESP}) as fat -F32"${Color_Off}
   mkfs.fat -F32 ${ESP}
   sync
fi

# create data partition
${dialog} --image="dialog-question" ${dyes} ${dno} --text="Would you like to create a data partition,\nto store, amongst whatever you\'d like, alphaOS system files?"
if [ ${?} = ${dyescode} ]; then
   rootPartLabel='data'
   
   echo -e ${BGreen}"==> "${BWhite}"creating data partition of remaining space on ${installDisk}"${Color_Off}
   
   exec 5>&1
   sgdiskOut=$(sgdisk --new=0:0:0 --change-name=0:"${rootPartLabel}" --typecode=0:8300 ${installDisk} | tee >(cat - >&5))
   exec 5<&-

   # record root partition
   rootPart=${installDisk}$(getpartnumfromsgdiskoutput "${sgdiskOut}")
   
   sync

   echo -e ${BGreen}"==> "${BWhite}"formatting data partition (${rootPart}) as ext4"${Color_Off}
   mkfs.ext4 ${rootPart}
   sync
fi
}

alphainst () {
installpartcheck || return

# copy alphaOS files
if [ ! -d "${alphaOSSrcDir}" ]; then
    echo -e ${BGreen}"==> "${BWhite}"ERROR: could not find alphaOS system files.\nPlease copy them manually to ${alphaOSInstPath}"${Color_Off}
    ${dialog} --image=dialog-error --text="See console output" --button='OK'
    return
fi

${dialog} --text="Do you want to copy all files in ${alphaOSSrcDir},\nor create a fresh install?" \
--button={'all files:2','fresh install:3'} ${dhome}
retVal=${?}

# mount root partition
mountpart ${rootPart} ${rootMount}

alphaOSInstPath="${rootMount}${alphaOSDir}"

case ${retVal} in
2)
   echo -e ${BGreen}"==> "${BWhite}"copying ${alphaOSSrcDir} to ${alphaOSInstPath}"${Color_Off}
   cp -fvR ${alphaOSSrcDir} "${alphaOSInstPath}"
   ;;
3)
   echo -e ${BGreen}"==> "${BWhite}"copying base system files from ${alphaOSSrcDir} to ${alphaOSInstPath}"${Color_Off}
   len=${#alphaOSFiles[@]}
   file=''
   
   for (( i=0; i < ${len}; i++ )); do
      file=${alphaOSFiles[${i}]}
      
      # must create directory of file first
      fileDir="$(echo "${alphaOSInstPath}${file}" | sed -r 's/\/[^\/]+$//')"
      mkdir -pv "${fileDir}"
      cp -fv {"${alphaOSSrcDir}","${alphaOSInstPath}"}"${file}"
   done
   ;;
${dhomecode})
   return
   ;;
esac

# clean up
unmountdir ${rootMount}
}

grubbiosinst () {
installdiskcheck || return
installpartcheck || return

${dialog} --image="dialog-warning" ${dyes} ${dno} --text="Will now install GRUB for BIOS at ${installDisk} and data files at ${rootPart}\nALL BOOT LOADER DATA ON THIS DISK WILL BE ERASED\nAre you affirmative you want to continue?"
if [ ${?} = ${dnocode} ]; then
   return
fi

echo -e ${BGreen}"==> "${BWhite}"installing GRUB for BIOS"${Color_Off}

mountpart ${rootPart} ${rootMount}

# need to specify root directory, else GRUB will complain about aufs
echo -e ${BGreen}"==> "${BWhite}"installing GRUB --target=i386-pc to ${installDisk} and data files to ${rootMount}"${Color_Off}
grub-install --target=i386-pc --root-directory=${rootMount} --recheck ${installDisk} --force
sync

unmountdir ${rootMount}

${dialog} ${dok} --text='Remember to configure GRUB :)'
}

grubuefiinst () {
# early support, no guarantees

# -- UEFI
# ~Wikipedia: UEFI, EFI System Partition
# ~Arch Wiki: GRUB#UEFI
# ~https://wiki.gentoo.org/wiki/GRUB2#UEFI.2FGPT
# ~https://www.gnu.org/software/grub/manual/grub.html
# -- Secure Boot
# ~http://www.rodsbooks.com/efi-bootloaders/secureboot.html
# ~https://www.suse.com/communities/conversations/uefi-secure-boot-details/
# ~http://www.zdnet.com/torvalds-clarifies-linuxs-windows-8-secure-boot-position-7000011918/
# ~http://www.zdnet.com/shimming-your-way-to-linux-on-windows-8-pcs-7000008246/
# ~https://wiki.ubuntu.com/SecurityTeam/SecureBoot

uefipartcheck || return
installpartcheck || return

#~ ${dialog} --image="dialog-warning" ${dyes} ${dno} --text=\
#~ "will now install GRUB for UEFI at ESP ${ESP} and data files at ${rootPart}
#~ 
#~ UEFI Secure Boot is not supported by alphainst.sh as of today.
#~ you need to disable Secure Boot, or look up other means to boot alphaOS,
#~ if you require UEFI. look it up in any case.
#~ this has been chosen as a user should not be forced to trust anyone
#~ in order to boot their programs.
#~ the web is full of details. exempli gratia:
#~ http://www.rodsbooks.com/efi-bootloaders/secureboot.html
#~ 
#~ is your mind set about continuing?"

echo \
"http://www.rodsbooks.com/efi-bootloaders/secureboot.html
https://fsf.org/campaigns/secure-boot-vs-restricted-boot/
http://www.zdnet.com/torvalds-clarifies-linuxs-windows-8-secure-boot-position-7000011918/
https://wiki.ubuntu.com/SecurityTeam/SecureBoot" | \
${dialog} --image="dialog-warning" ${dyes} ${dno} --text=\
"UEFI Secure Boot is not supported by alphainst.sh as of today.
this has been chosen as a user should not be forced to trust anyone
in order to boot their programs.

meanwhile, regular UEFI booting is definitely supported :)
you just need to disable Secure Boot in your firmware,
or look up other means to boot alphaOS if you require Secure Boot.
look it up in any case.

will now install GRUB for UEFI at ESP ${ESP} and data files at ${rootPart}
is your mind set about continuing?

the web is full of details. exempli gratia:" --text-info --show-uri
if [ ${?} = ${dnocode} ]; then
   return
fi

echo -e ${BGreen}"==> "${BWhite}"installing GRUB for UEFI"${Color_Off}

# need ESP for UEFI files and root partition for /boot folder
mountpart ${ESP} ${ESPMount}
mountpart ${rootPart} ${rootMount}

echo -e ${BGreen}"==> "${BWhite}"installing GRUB --target=x86_64-efi to EFI directory ${ESPMount} and data files to ${rootMount}"${Color_Off}
# preload GPT, fat and video modules. consulting Arch Wiki#GRUB can be an idea for possible fixes
preloadEfiModules="part_gpt part_msdos fat all_video"
grub-install --target=x86_64-efi --efi-directory=${ESPMount} --bootloader-id=grub \
--root-directory=${rootMount} --recheck --removable --modules="${preloadEfiModules}"
sync

unmountdir ${rootMount}
unmountdir ${ESPMount}

${dialog} ${dok} --text='Remember to configure GRUB :)'
}

grubcfg () {
installpartcheck || return

mountpart ${rootPart} ${rootMount}

# just create the grub.cfg ourselves :D
#   https://www.gnu.org/software/grub/manual/html_node/Multi_002dboot-manual-config.html
#   https://wiki.archlinux.org/index.php/Grub#Manually_creating_grub.cfg

# get UUID of root partition
rootPartUUID=`lsblk --noheadings --output UUID ${rootPart}`

${dialog} --image='dialog-question' ${dyes} ${dno} \
--text="Will now overwrite ${grubcfgfile}\nAre you in no doubt you want to continue?"
if [ ${?} = ${dnocode} ]; then
   unmountdir ${rootMount}
   return
fi

echo -e ${BGreen}"==> "${BWhite}"configuring GRUB"${Color_Off}

echo -e ${BGreen}"==> "${BWhite}"writing built-in GRUB config to ${grubcfgfile}"${Color_Off}
cat << __GRUBCFG__ > ${grubcfgfile}
# GRUB config. suit yourself
set rootPartUUID=${rootPartUUID}
set alphaOSDir=${alphaOSDir}
set default=0
set timeout=5

menuentry "alphaOS GNU/Linux usbmode" {
   insmod part_gpt
   insmod ext2
   insmod search_fs_uuid
   
   search --fs-uuid --no-floppy --set=root \${rootPartUUID}
   
   echo 'Loading alphaOS GNU/Linux kernel ...'
   linux \${alphaOSDir}/boot/vmlinuz from=\${alphaOSDir} fsck usbmode
   echo 'Loading alphaOS GNU/Linux kernel initrd ...'
   initrd \${alphaOSDir}/boot/initrfs.img
}

menuentry "alphaOS GNU/Linux" {
   insmod part_gpt
   insmod ext2
   insmod search_fs_uuid
   
   search --fs-uuid --no-floppy --set=root \${rootPartUUID}
   
   echo 'Loading alphaOS GNU/Linux kernel ...'
   linux \${alphaOSDir}/boot/vmlinuz from=\${alphaOSDir} fsck
   echo 'Loading alphaOS GNU/Linux kernel initrd ...'
   initrd \${alphaOSDir}/boot/initrfs.img
}

menuentry "alphaOS GNU/Linux usbmode toram" {
   insmod part_gpt
   insmod ext2
   insmod search_fs_uuid
   
   search --fs-uuid --no-floppy --set=root \${rootPartUUID}
   
   echo 'Loading alphaOS GNU/Linux kernel ...'
   linux \${alphaOSDir}/boot/vmlinuz from=\${alphaOSDir} fsck usbmode toram
   echo 'Loading alphaOS GNU/Linux kernel initrd ...'
   initrd \${alphaOSDir}/boot/initrfs.img
}

menuentry "alphaOS GNU/Linux debug" {
   insmod part_gpt
   insmod ext2
   insmod search_fs_uuid
   
   search --fs-uuid --no-floppy --set=root \${rootPartUUID}
   
   echo 'Loading alphaOS GNU/Linux kernel ...'
   linux \${alphaOSDir}/boot/vmlinuz from=\${alphaOSDir} usbmode debug
   echo 'Loading alphaOS GNU/Linux kernel initrd ...'
   initrd \${alphaOSDir}/boot/initrfs.img
}

menuentry "alphaOS GNU/Linux fresh" {
   insmod part_gpt
   insmod ext2
   insmod search_fs_uuid
   
   search --fs-uuid --no-floppy --set=root \${rootPartUUID}
   
   echo 'Loading alphaOS GNU/Linux kernel ...'
   linux \${alphaOSDir}/boot/vmlinuz from=\${alphaOSDir} fresh
   echo 'Loading alphaOS GNU/Linux kernel initrd ...'
   initrd \${alphaOSDir}/boot/initrfs.img
}

menuentry "Windows 7" {
  insmod part_msdos
  insmod ntfs
  
  set root=(hd0,msdos1)
  chainloader +1
}

__GRUBCFG__
sync

# open in text editor for interactivity
if [ -n "${EDITOR}" ]; then
    ${EDITOR} ${grubcfgfile}
fi

unmountdir ${rootMount}
}

grubmenu () {
# check if already installed
installedForBIOS='idk'
if [ -n "${installDisk}" ]; then
   # MBR is the first 512 bytes in MBR disks. need to grep --text, as output of dd is binary
   ddout=$(dd if=${installDisk} bs=512 count=1 2>/dev/null | grep --text 'GRUB')
   if [ -n "${ddout}" ]; then
      installedForBIOS='YES'
   else
      installedForBIOS='NO'
   fi
fi
installedForUEFI='idk'
if [ -n "${ESP}" ]; then
   mountpart ${ESP} ${ESPMount}
   bootEfiApp="${ESPMount}/EFI/BOOT/BOOTX64.EFI"
   if [ -e "${bootEfiApp}" ] && [ -n "$(cat "${bootEfiApp}" | grep 'GRUB')" ]; then
      installedForUEFI='YES'
   else
      installedForUEFI='NO'
   fi
   unmountdir ${ESPMount}
fi
configFileExists='idk'
if [ -e "${rootPart}" ]; then
   mountpart ${rootPart} ${rootMount}
   if [ -e "${grubcfgfile}" ]; then
      configFileExists='YES'
   else
      configFileExists='NO'
   fi
   unmountdir ${rootMount}
fi

# GRUB dialog
${dialog} --text="GRUB: GRand Unified Bootloader

chosen install disk: ${installDisk}
chosen data partition: ${rootPart}
chosen EFI System Partition: ${ESP}

installed for BIOS on ${installDisk}: ${installedForBIOS}
installed for UEFI on ${ESP}: ${installedForUEFI}
config file exists at ${grubcfgfile}: ${configFileExists}" \
--button={'install for BIOS:2','install for UEFI:3','configure GRUB:4'} ${dhome}
case ${?} in
2)
   grubbiosinst
   ;;
3)
   grubuefiinst
   ;;
4)
   grubcfg
   ;;
${dhomecode})
   return
   ;;
esac

grubmenu
}

menu () {
retChoices=$(${dialog} --text-align="center" --title="System Installer" \
--text="Welcome!\nYou are expected to have read the alphaOS readmes at Right-click -> Readme. That's about it :)\n" \
--form --align=right \
--field="Install to disk:CB" "$(getdisks)" \
--field="Copy files to partition:CB" "$(getpartitions)" \
--field="(EFI System Partition):CB" "$(getESPs)" \
--button={"Clean and format disk:2","Copy alphaOS files:3","Set up boot loader:4"} \
${dquit})

retVal=${?}

# process choices
# if the dialog had no choice, '(null)' is returned. we substitute that with ''
retChoices=$(echo "${retChoices}" | sed 's/(null)//g')
installDisk=$(echo "${retChoices}" | cut -d '|' -f 1 | cut -d ' ' -f 1)
rootPart=$(echo "${retChoices}" | cut -d '|' -f 2 | cut -d ' ' -f 1)
ESP=$(echo "${retChoices}" | cut -d '|' -f 3 | cut -d ' ' -f 1)

case ${retVal} in
2)
   preparedisk
   ;;
3)
   alphainst
   ;;
4)
   grubmenu
   ;;
${dquitcode})
   exit 0
   ;;
esac

menu
}
# -------------------------------
# ---------- Functions ----------
# -------------------------------

# -------------------------------
# ---------- Execution ----------
# -------------------------------

# are we root?
privcheck

# ensure dependencies are met
depensure

# show menu
menu

# -------------------------------
# ---------- Execution ----------
# -------------------------------
