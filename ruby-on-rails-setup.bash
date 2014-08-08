#!/bin/bash

# check for root.  Don't continue if we aren't root
if [ "$(id -u)" != "0" ]; then
    echo "Cannot setup system.  Must be root."
    exit 1
fi

# install packages
pacman -S --needed --noconfirm ruby ruby-docs nodejs

# setup for ruby gems
echo ""
echo "# Make sure ruby gems stuff is in the path" >> $HOME/.bashrc
echo "export PATH=\"${PATH}:/opt/cisco/vpn/bin\"" >> $HOME/.bashrc
