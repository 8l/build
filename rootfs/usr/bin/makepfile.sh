#!/usr/bin/bash
#
# Copyright (c) alphaOS
# Written by simargl <archpup-at-gmail-dot-com>
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
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# VARIABLES

SAVEFILE_NAME="changes.fs4"

TEXT="All of your settings and additional software that you install, 
will be stored within the save file, by default, so it can 
become quite large if not managed. I suggest you keep all
of your documents and photos etc. in another location.

Please select desired size bellow. Savefile will be created on
system partition inside directory where the installation 
files reside.
"

MESSAGE="File $SAVEFILE_NAME created successfully! Personal file 
will be mounted and used to save your settings.
"

ERROR="Error! File $SAVEFILE_NAME could not be created!
"

# DISCOVER PARTITION AND FRUGAL INSTALLATION DIRECTORY

SYSTEM_DIR="/mnt/live/memory/data"
SAVEFILE_PARTITION=$(mount | grep $SYSTEM_DIR | grep -v squashfs | cut -d" " -f1)

if [ $SAVEFILE_PARTITION == "/dev/sr0" ]; then
  INFO=`yad --title="Savefile creator for alphaOS" --text="$ERROR Read-only file system." \
  --image="dialog-error-symbolic" --fixed --window-icon="dialog-error-symbolic" --center \
  --button="OK:0"`
  exit 1
fi

cmdline_value()
{
   cat /proc/cmdline | egrep -o "(^|[[:space:]])$1=[^[:space:]]+" | tr -d " " | cut -d "=" -f 2- | tail -n 1
}

FROM="$(cmdline_value from)"

if [ "$FROM" != "" ]; then
  SAVEFILE_DIR="$SYSTEM_DIR$FROM"
else
  for DIRECTORY in $(find $SYSTEM_DIR -maxdepth 1 -mindepth 1 -type d | grep -v lost+found ); do
    if [ -f $DIRECTORY/boot/vmlinuz -a -f $DIRECTORY/alpha*sb ]; then
      SAVEFILE_DIR="$DIRECTORY"
    fi
  done
fi

SAVEFILE_DIR_SHORT=$(echo $SAVEFILE_DIR | sed 's|/mnt/live/memory/data/||g')

# QUESTION DIALOGS

SETUP=`yad --title="Savefile creator for alphaOS" --text="$TEXT" \
--window-icon="application-x-fs4" --center --fixed --form \
--field="Savefile Size   MB:NUM" "200!0..5120!100" \
--button="OK:0" --button="Cancel:1"`

ret=$?
[[ $ret -ne 0 ]] && exit 1

SAVEFILE_SIZE=$(echo $SETUP | cut -d "|" -f 1 | cut -f1 -d".")
QUESTION="Do you want to create personal file $SAVEFILE_NAME 
with size of $SAVEFILE_SIZE MB on partition $SAVEFILE_PARTITION?
Frugal installation found in $SAVEFILE_DIR_SHORT directory.
"

INFO=`yad --title="Savefile creator for alphaOS" --text="$QUESTION" \
--image="dialog-question-symbolic" --center --fixed --window-icon="dialog-question-symbolic" \
--button="OK:0" --button="Cancel:1"`

ret=$?
[[ $ret -ne 0 ]] && exit 1

# ERROR
if [ -f $SAVEFILE_DIR/$SAVEFILE_NAME ]; then
  INFO=`yad --title="Savefile creator for alphaOS" --text="$ERROR File already exists." \
  --image="dialog-error-symbolic" --center --fixed --window-icon="dialog-error-symbolic" \
  --button="OK:0"`
  exit 1
fi

# MAKE SAVEFILE
cd $SAVEFILE_DIR
dd if=/dev/zero of=$SAVEFILE_NAME bs=1M count=$SAVEFILE_SIZE	
mkfs.ext4 -q -m 0 -F $SAVEFILE_NAME
echo "SAVEFILE=\"$SAVEFILE_DIR/$SAVEFILE_NAME\"" > /tmp/savefile.txt

EXIT=`yad --title="Savefile creator for alphaOS" --text="$MESSAGE" \
--image="dialog-information-symbolic" --center --fixed --window-icon="dialog-information-symbolic" \
--button="OK:0"`
