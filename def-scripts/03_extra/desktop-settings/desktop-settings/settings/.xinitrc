export XDG_RUNTIME_DIR="/var/wayland/${UID}-runtime-dir"
export WINDOW_MANAGER="openbox"

~/.start &
exec dbus-launch $WINDOW_MANAGER