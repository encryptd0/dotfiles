#!/bin/bash

#killall -9 waybar
#waybar & 

# Check if waybar is running
if pgrep -x "waybar" > /dev/null; then
    # If Waybar is running, kill it
    killall -9 waybar
else
    # If Waybar is not running, start it
    waybar &
fi


