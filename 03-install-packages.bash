#!/bin/bash

### This script is written for Arch Linux ###

echo "This script will install a bunch of packages that Ben deems necessary for a proper system."

# check for root.  Don't continue if we aren't root
if [ "$(id -u)" != "0" ]; then
    echo "Cannot setup system.  Must be root."
    exit 1
fi

USERNAME=""

if $(cat /etc/passwd | grep "1000" > /dev/null); then
    USERNAME=$(cat /etc/passwd | grep "1000" | sed -e 's/:x:.*//g')
    read -p "Is the name of your non-root user \"${USERNAME}\"? (Y/N): " CONF
    if ! [ "$CONF" = "Y" -o "$CONF" = "y" ]; then
        USERNAME=""
    fi
fi

if [ -z "$USERNAME" ]; then
    echo "Please enter the name of the non-root user you want to create (or leave blank for none)"
    read -p "New user: " USERNAME

    # Add the user to the groups if we're supposed to. Make sure the user exists
    if [ -n "$USERNAME" ]; then
        if ! $(cat /etc/passwd | grep "^${USERNAME}" >/dev/null); then
            useradd -m "$USERNAME"
            echo "Please enter a password for the user \"${USERNAME}\""
            passwd $USERNAME
        fi
    fi
fi

aurinstall ()
{
    AUR_DIR="$HOME/aur"
    AUR_BUILD_DIR="$AUR_DIR/build"
    AUR_TARBALLS_DIR="$AUR_DIR/tarballs"
    AUR_ARCHIVE_DIR="/var/cache/aur"

    mkdir -p "$AUR_TARBALLS_DIR"

    prevdir=$(pwd)

    use_cower=0
    if [ -f "$1" ]; then
        [ "$1" -ef "$AUR_TARBALLS_DIR/$(basename $1)" ] || cp "$1" "$AUR_TARBALLS_DIR/"
    elif [[ "$1" =~ ^http ]]; then
        cd "$AUR_TARBALLS_DIR"
        curl -O "$1"
    else
        use_cower=1
    fi

    if (( $use_cower )); then
        if $(which cower > /dev/null 2>&1); then
            cd $AUR_BUILD_DIR
            cower -d -d "$1"
            output_dir="$1"
        else
            echo "cower is not installed, and you did not pass a tarball or URL. Cannot install package"
            exit 1
        fi
    else
        tarball="$(basename $1)"
        # output_dir="$(echo $tarball | sed -e 's/\.t.*//g')" # To support .tgz files
        output_dir="$(echo $tarball | sed -e 's/\.tar.*//g')"
        cd "$AUR_BUILD_DIR"
        tar xf "$AUR_TARBALLS_DIR/$tarball"
    fi

    cd "$output_dir"
    makepkg --asroot --clean --syncdeps --needed --noconfirm --install
    cp *.tar.* "$AUR_ARCHIVE_DIR"
}


if [ -n "$USERNAME" ]; then
    read -p "Do you want to make \"$USERNAME\" a sudoer and lock the root accounts password?: " LOCK_ROOT

    if [ "$LOCK_ROOT" = "y" -o "$LOCK_ROOT" = "Y" ]; then
        pacman -S --needed --noconfirm sudo

        groupadd wheel
        usermod -a -G wheel $USERNAME

        # allow passworded sudo in the sudoers file
        echo "" >> /etc/sudoers
        echo "# Added by setup script" >> /etc/sudoers
        echo "# Allow members of the wheel group sudo access" >> /etc/sudoers
        echo "%wheel    ALL=(ALL) ALL" >> /etc/sudoers

        # lock the root account
        passwd -l root
    fi
fi

read -p "Are you installing this as a guest VirtualBox VM?" GUESTVM
read -p "Do you want to install the CK kernel?: " LINUXCK
read -p "Do you want to install a graphical environment (Gnome)?: " GNOME
read -p "Do you want to install the offline wiki docs? (around 130 MB): " OFFLINEDOCS
# Offline wiki docs are installed to /usr/share/doc/arch-wiki


NETMAN=n
if [ "$GNOME" = "Y" -o "$GNOME" = "y" ]; then
    read -p "Do you want to add the main user to the groups: audio,lp,optical,storage,video,wheel,games,power,scanner?: " GROUPS
    read -p "Do you want to install Network Manager?: " NETMAN
fi

LIBREOFFICE=n
if [ "$GNOME" = "Y" -o "$GNOME" = "y" ]; then
    read -p "Do you want to install LibreOffice?: " LIBREOFFICE
fi

# Ask about installing libvirt if the CPU supports virtualization and we're not in a VBox already
if [ "$GUESTVM" != "Y" ] && [ "$GUESTVM" != "y" ]; then
    if $(egrep "vmx|svm" /proc/cpuinfo > /dev/null); then
        echo "Your CPU supports virtual machine hardware acceleration"
        read -p "Do you want to install libvirt/QEMU/KVM?: " LIBVIRT
        read -p "Do you want to install VirtualBox?: " VBOX
    else
        echo "Your CPU DOES NOT support virtual machine hardware acceleration."
        echo "You can install libvirt/QEMU without KVM but it will run dog slow."
        read -p "Do you want to install libvirt/QEMU anyway (without KVM)?: " LIBVIRT
        read -p "Do you want to install VirtualBox?: " VBOX
    fi
fi

# read -p "Do you want to install Netflix?: " NETFLIX
# read -p "Do you want to install Dropbox?: " DROPBOX
read -p "Do you want to install Insync?: " INSYNC


# Full repo sync and system upgrade
pacman -Syu --noconfirm


# Install non-graphical stuff
pacman -S --noconfirm --needed base-devel
pacman -S --noconfirm --needed iproute2 iw wpa_supplicant
pacman -S --noconfirm --needed vim
pacman -S --noconfirm --needed git
pacman -S --noconfirm --needed xclip
pacman -S --noconfirm --needed dcfldd
pacman -S --noconfirm --needed unrar
pacman -S --noconfirm --needed nmap
pacman -S --noconfirm --needed wireshark-gtk
pacman -S --noconfirm --needed python-pip
pacman -S --noconfirm --needed python-crypto
pacman -S --noconfirm --needed bc
pacman -S --noconfirm --needed linux-headers
pacman -S --noconfirm --needed htop
pacman -S --noconfirm --needed lsof
pacman -S --noconfirm --needed p7zip
pacman -S --noconfirm --needed bash-completion
pacman -S --noconfirm --needed avahi
pacman -S --noconfirm --needed nss-mdns
pacman -S --noconfirm --needed openssh
pacman -S --noconfirm --needed dnsutils
pacman -S --noconfirm --needed lm_sensors

pacman -S --noconfirm --needed pkgfile
pkgfile --update

aurinstall "https://aur.archlinux.org/packages/co/cower/cower.tar.gz"
aurinstall anything-sync-daemon
aurinstall wavemon

if [ "$INSYNC" = "Y" -o "$INSYNC" = "y" ]; then
    aurinstall insync
fi

if [ "$OFFLINEDOCS" = "Y" -o "$OFFLINEDOCS" = "y" ]; then
    pacman -S --noconfirm --needed arch-wiki-docs arch-wiki-lite
fi


# setup avahi/mdns
tfile=$(mktemp)
while read line; do
    if ! $(echo "$line" | grep 'mdns_minimal' > /dev/null); then
           echo "$line" | sed -e 's/hosts: files/hosts: files mdns_minimal [NOTFOUND=return]/g' >> "$tfile"
       else
           echo "$line" >> "$tfile"
    fi
done < "/etc/nsswitch.conf"
cp "$tfile" /etc/nsswitch.conf


# if we install network manager then we don't want this
if ! [ "$NETMAN" = "Y" -o "$NETMAN" = "y" ]; then
    pacman -S --noconfirm --needed ntp
fi


# Install graphical stuff
if [ "$GNOME" = "Y" -o "$GNOME" = "y" ]; then
    pacman -S --noconfirm --needed xorg-server xorg-server-utils xorg-utils xorg-apps xorg-xinit
    pacman -S --noconfirm --needed gnome
    pacman -S --noconfirm --needed terminator
    pacman -S --noconfirm --needed gedit
    pacman -S --noconfirm --needed gnome-tweak-tool
    pacman -S --noconfirm --needed recordmydesktop
    pacman -S --noconfirm --needed xdotool
    pacman -S --noconfirm --needed imagemagick imagemagick-doc
    pacman -S --noconfirm --needed eog
    pacman -S --noconfirm --needed qalculate-gtk # a freaking awesome calculator
    pacman -S --noconfirm --needed dconf
    pacman -S --noconfirm --needed firefox
    pacman -S --noconfirm --needed transmission-gtk
    pacman -S --noconfirm --needed vlc
    pacman -S --noconfirm --needed libdvdcss
    pacman -S --noconfirm --needed ttf-freefont
    pacman -S --noconfirm --needed unetbootin
    pacman -S --noconfirm --needed fbreader
    pacman -S --noconfirm --needed xchat
    pacman -S --noconfirm --needed gimp
    pacman -S --noconfirm --needed pinta
    pacman -S --noconfirm --needed handbrake
    pacman -S --noconfirm --needed gst-plugins-base gst-plugins-base-libs
    pacman -S --noconfirm --needed gst-plugins-good
    pacman -S --noconfirm --needed gst-plugins-bad
    pacman -S --noconfirm --needed gst-plugins-ugly
    pacman -S --noconfirm --needed vino vinagre # VLC server and remote viewer Gnome style

    if [ "$LIBREOFFICE" = "y" -o "$LIBREOFFICE" = "Y" ]; then
        pacman -S --noconfirm --needed libreoffice-base libreoffice-calc libreoffice-common \
        libreoffice-draw libreoffice-en-US libreoffice-gnome libreoffice-impress libreoffice-math \
        libreoffice-writer
    fi

    # Install Network Manager
    # If Network Manager needs to be disabled, it should be masked because it automatically starts through dbus
    # systemctl mask NetworkManager
    # systemctl mask NetworkManager-dispatcher

    if [ "$NETMAN" = "Y" -o "$NETMAN" = "y" ]; then
        pacman -S --noconfirm --needed networkmanager network-manager-applet
        pacman -S --noconfirm --needed networkmanager-dispatcher-openntpd

        systemctl enable NetworkManager
        systemctl enable NetworkManager-dispatcher.service

        echo "dhcp=dhcpcd" >> /etc/NetworkManager/NetworkManager.conf
    fi

    aurinstall profile-sync-daemon
    aurinstall libgcrypt15
    aurinstall python-pylast
    aurinstall ttf-ms-fonts
    aurinstall pithos
    aurinstall google-chrome

    if [ "$INSYNC" = "Y" -o "$INSYNC" = "y" ]; then
        aurinstall insync-nautilus
    fi


    # Set up /etc/psd.conf
    PSD_USER="$USERNAME"
    if [ -z "$PSD_USER" ]; then
        PSD_USER="ben"
    fi
    tmpfile=$(mktemp)
    while read line; do
        # Order here is important
        if $(echo "$line" | egrep "^#" > /dev/null); then
            echo "$line" >> $tmpfile
        elif $(echo "$line" | grep "USERS" > /dev/null); then
            echo "USERS=\"$PSD_USER\"" >> $tmpfile
        else
            echo "$line" >> $tmpfile
        fi
    done < "/etc/psd.conf"

fi

if [ -n "$GROUPS" ] && [ -n "$USERNAME" ]; then
    usermod -a -G audio,lp,optical,storage,video,wheel,games,power,scanner $USERNAME
fi

# Install linux-ck if the user so desires
if [ "$LINUXCK" = "y" -o "$LINUXCK" = "Y" ]; then
    cd /tmp
    mkdir -p linuxckbuild
    cd linuxckbuild
    cower -d linux-ck
    cd linux-ck

    # Enable BFQ in the makepkg
    while read line; do
        if $(echo "$line" | grep "_BFQ_enable_" >/dev/null); then
            echo "_BGQ_enable_=y" >> PKGBUILD.TMP
        else
            echo "$line" >> PKGBUILD.TMP
        fi
    done < PKGBUILD

    cp PKGBUILD.TMP PKGBUILD
    makepkg --syncdeps --noconfirm --install

    # Regenerate Grub configuration to include this new kernel
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# Install VirtualBox Guest Modules if in a VBox VM
if [ "$GUESTVM" = "y" -o "$GUESTVM" = "Y" ]; then
    pacman -S --noconfirm --needed virtualbox-guest-modules virtualbox-guest-utils

    VBOX_CONF="/etc/modules-load.d/virtualbox.conf"

    echo "vboxguest" > "$VBOX_CONF"
    echo "vboxsf" >> "$VBOX_CONF"
    echo "vboxvideo" >> "$VBOX_CONF"
fi

# Install VirtualBox
if [ "$VBOX" = "Y" -o "$VBOX" = "y" ]; then
    VBOX_CONF="/etc/modules-load.d/virtualbox.conf"

    if [ "$LINUXCK" = "y" -o "$LINUXCK" = "Y" ]; then
        pacman -S --noconfirm --needed dkms virtualbox-host-dkms virtualbox-guest-dkms
        aurinstall virtualbox-ck-host-modules
    fi

    pacman -S --noconfirm --needed virtualbox virtualbox-host-modules qt4
    pacman -S --noconfirm --needed net-tools
    pacman -S --noconfirm --needed virtualbox-guest-iso

    echo "vboxdrv" > "$VBOX_CONF"
    echo "vboxnetadp" >> "$VBOX_CONF"
    echo "vboxnetflt" >> "$VBOX_CONF"
    echo "vboxpci" >> "$VBOX_CONF"

    groupadd vboxusers
    usermod -a -G vboxusers $USERNAME
fi

# Install libvirt
if [ "$LIBVIRT" = "Y" -o "$LIBVIRT" = "y" ]; then
    echo "Libvirt install not implemented"
    pacman -S --noconfirm --needed libvirt virt-manager bridge-utils dnsmasq virtviewer ebtables qemu

    if [ -n "$USERNAME" ]; then
        groupadd libvirt
        usermod -a -G libvirt,kvm $USERNAME
    fi

read -r -d '' VAR <<"EOF"
    polkit.addRule(function(action, subject) {
        if (action.id == "org.libvirt.unix.manage" &&
            subject.isInGroup("libvirt")) {
                return polkit.Result.YES;
        }
    });
EOF
    echo "$VAR" > /etc/polkit-1/rules.d/50-org.libvirt.unix.manage.rules
fi

# If in a VM like KVM/QEMU
# pacman -S --noconfirm mesa xf86-video-vesa

# If Nvidia graphics card:
# pacman -S --noconfirm libva-vdpau-driver nvidia-304xx

# If Intel graphics card:
# pacman -S --noconfirm libva-intel-driver xf86-video-intel


# Enable desired services 

# We need ntpd if we didn't install NetworkManager
if ! [ "$NETMAN" = "Y" -o "$NETMAN" = "y" ]; then
    echo "Enabling and starting ntpd..."
    systemctl enable ntpd.service
    systemctl start ntpd.service
fi

systemctl enable avahi-daemon.service
systemctl start avahi-daemon.service

systemctl enable sshd.service
systemctl start sshd.service

if [ "$GNOME" = "Y" -o "$GNOME" = "y" ]; then
    systemctl enable psd.service psd-resync.service
fi

if [ "$LIBVIRT" = "Y" -o "$LIBVIRT" = "y" ]; then
    systemctl enable libvirtd.service
    systemctl enable libvirt-guests.service
fi


if [ -f "setupArch-as-user.bash" ] && [ -n "$USERNAME" ]; then
    sudo -u $USERNAME setupArch-as-user.bash
else
    echo "All done.  You should now run the as-user script as your regular user"
fi

