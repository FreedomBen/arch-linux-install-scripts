#!/bin/bash

FDISK="$(which fdisk)"

echo "Partitioning can be a tricky problem because there are many different possible configurations."
echo "This script will ask you some questions and then make a suggestion that you can take or leave."

read -p "Are you using UEFI/GPT? (y/[n]): " UEFI
read -p "Are you using full disk encryption (Luks) (y/[n]): " LUKS

if [[ "$UEFI" =~ [yY] ]]; then
    FDISK="$(which gdisk)"
fi


