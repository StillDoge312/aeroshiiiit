#!/bin/bash
cd "$(dirname "$0")" || exit 1
exec "/var/home/stilldoge312/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64" "$@"
