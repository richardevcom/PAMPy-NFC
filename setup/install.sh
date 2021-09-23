#!/bin/bash

# Run: sudo /bin/bash install.sh -u http://example.com/api

printf "\n\n██████  ██████  ██████  ███████ ██ ██████"
printf "\n██   ██ ██   ██ ██   ██ ██      ██ ██   ██"
printf "\n██████  ██████  ██████  █████   ██ ██   ██"
printf "\n██      ██      ██   ██ ██      ██ ██   ██"
printf "\n██      ██      ██   ██ ██      ██ ██████\n\n"

printf "          PAM Python RFID 2FA\n\n"

# Prepare args
while getopts u: flag
do
    case "${flag}" in
        u) url=${OPTARG};;
    esac
done

# Check if user running as root
if [ "$EUID" -ne 0 ]
  then printf "✖ You don't have sufficent permissions.
   Please run as sudo. Exiting..."
  exit 1
fi

# Check if URL argument is provided
if [ -z "$url" ]
then
    printf "✖ Error connecting to API URL.
   Please provide API endpoint URL ussing -u argument:
   for example \"install.sh -u http://localhost/api/\"\n"
    exit 1
else
    # Test API endpoint URL
    echo "❐ Testing API endpoint URL $url ..."
    url_status=$(curl -Is "$url" | head -1)

    # Check HTTP status of the URL
    if [ -z "$url_status" ]
    then
        echo "✖ Connection to $url was timed out. Exiting..."
        exit 1
    else
        # API worked so we can continue
        echo "✔ Connected to $url."

        # Update system before install
        echo "❐ Updating system packages..."
        apt-get -y update &>/dev/null
        echo "✔ System packages updated!"

        # Prepare temp folder
        echo "❐ Preparing temp folder..."
        temp_dir="$HOME/temp"
        # Check if temp doesn't already exist
        if [ ! -d $temp_dir ]
        then
            mkdir $temp_dir
            echo "✔ Temporary directory $temp_dir created."
        else
            echo "✖ Temp folder already exists. Skipping..."
        fi

        # Install git
        echo "❐ Preparing git..."
        # Check if git is installed
        git_not_set=$(git --version 2>&1 >/dev/null)
        if [ ! -z "$git_not_set" ]
        then
            apt-get -y install git &>/dev/null
            echo "✔ Git installed."
        else
            echo "✖ Git already installed. Skipping..."
        fi

        # Pull repo files
        ppnfc_dir="$temp_dir/ppnfc"
        ppnfc_repo="https://github.com/richardevcom/PAMPyNFC"
        echo "❐ Cloning PAMpy NFC files from $ppnfc_repo..."
        # Remove previous repo if exists
        rm -rf $ppnfc_dir &>/dev/null
        # Clone files
        git clone $ppnfc_repo $ppnfc_dir &>/dev/null
        echo "✔ PAMpy NFC files cloned into $ppnfc_dir"

        # Install PCSC tools
        echo "❐ Installing PC/SC tools..."
        apt-get -y install pcscd pcsc-tools &>/dev/null
        echo "✔ PC/SC tools installed."

        # Blacklist pre-existing drivers
        echo "❐ Blacklisting pre-existing PC/SC drivers..."
        mp_blacklist_conf=/etc/modprobe.d/blacklist.conf
        if ! grep -q "blacklist nfc" "$mp_blacklist_conf"
        then
            printf "\n# Disable default NFC drivers @richardev\nblacklist nfc\n" | tee -a $mp_blacklist_conf &>/dev/null
            modprobe -rf nfc &>/dev/null
            echo "✔ nfc driver blacklisted."
        fi
        if ! grep -q "blacklist pn533" "$mp_blacklist_conf"
        then
	        printf "blacklist pn533\n" | tee -a $mp_blacklist_conf &>/dev/null
            modprobe -rf pn533 &>/dev/null
            echo "✔ pn533 driver blacklisted."
        fi
        if ! grep -q "blacklist pn533_usb" "$mp_blacklist_conf"
        then
	        printf "blacklist pn533_usb\n" | tee -a $mp_blacklist_conf &>/dev/null
            modprobe -rf pn533_usb &>/dev/null
            echo "✔ pn533_usb driver blacklisted."
        fi
        echo "✔ Pre-existing drivers successfully blacklisted."

        # Install PCSC driver
        echo "❐ Installing PC/SC driver..."
        yes | dpkg -i $ppnfc_dir/lib/driver/libacsccid1_1.1.8-1~ubuntu18.04.1_amd64 &>/dev/null
        echo "✔ PC/SC driver installed."

        # Restart PC/SC service before continuing
        echo "❐ Restarting PC/SC service..."
        sudo /etc/init.d/pcscd restart &>/dev/null
        echo "✔ PC/SC service restarted."

        # Install python packages
        echo "❐ Installing Python & Python modules..."
        apt-get -y install python3 python3-pip python3-pyscard python3-evdev python3-serial python3-filelock python3-psutil python3-cryptography python3-xdo python3-setproctitle python3-requests python3-xlib python3-tk &>/dev/null
        echo "✔ Python & Python modules installed."

        # Rewrite URL for config
        echo "❐ Setting up API url in config file..."
        sed -Ei "s|http:\/\/127.0.0.1\/api\/|$url|g" $ppnfc_dir/conf/ppnfc_config.py &>/dev/null
        echo "✔ API url set in config."

        # Copying PAMpy NFC files
        echo "❐ Placing PAMpy NFC files accross system..."
        yes | cp -rf $ppnfc_dir/bin/scripts/* /usr/local/bin &>/dev/null
        yes | cp -rf $ppnfc_dir/conf/services/*.service /lib/systemd/system &>/dev/null
        yes | cp -rf $ppnfc_dir/bin/ppnfc_pam.config /usr/share/pam-configs &>/dev/null
        yes | cp -rf $ppnfc_dir/bin/themes/breeze/Login.qml /usr/share/sddm/themes/breeze/ &>/dev/null
        yes | cp -rf $ppnfc_dir/bin/themes/breeze/Main.qml /usr/share/sddm/themes/breeze/ &>/dev/null
        echo "✔ PAMpy NFC files deployed."

        # LOG file
        # echo "❐ Touching log file... (ㆆ _ ㆆ)"
        # touch /var/log/ppnfc.log &>/dev/null
        # echo "✔ Log file had enough of you."

        # Permissions
        echo "❐ Setting up PAMpy NFC file & folder permissions..."
        chown -R root:root /usr/local/bin/ppnfc_* &>/dev/null
        chown -R root:root /lib/systemd/system/ppnfc_* &>/dev/null
        chown -R root:root /etc/profile.d/ppnfc_display &>/dev/null
        chmod +x /usr/local/bin/ppnfc_* &>/dev/null
        chmod +x /lib/systemd/system/ppnfc_* &>/dev/null
        chmod +x /etc/profile.d/ppnfc_display &>/dev/null
        # Log
        # chown -R root:root /var/log/ppnfc.log &>/dev/null
        # chmod 0644 /var/log/ppnfc.log &>/dev/null
        echo "✔ Permissions set for PAMpy NFC files & folders."

        # Enable & start PAMpy NFC
        echo "❐ Enable & start PAMpy NFC services"
        systemctl enable ppnfc_server &>/dev/null
        systemctl start ppnfc_server &>/dev/null

        systemctl enable ppnfc_keyboard_wedge &>/dev/null
        systemctl start ppnfc_keyboard_wedge &>/dev/null

        systemctl enable ppnfc_auto_enter &>/dev/null
        systemctl start ppnfc_auto_enter &>/dev/null
        echo "✔ PAMpy NFC services ready."

        # Fix pam_unix.so delay
        echo "❐ Adding nodelay parameter to Unix PAM..."
        sed -i ':a;N;$!ba;s/Auth:\n\t*\s*\[success=end\s*\t*default=ignore\]\s*\t*pam_unix.so\s*\t*/Auth:\n\t[success=end default=ignore]\tpam_unix.so\tnodelay\t/g' /usr/share/pam-configs/unix &>/dev/null
        sed -i ':a;N;$!ba;s/Auth-Initial:\n\t*\s*\[success=end\s*\t*default=ignore\]\s*\t*pam_unix.so\s*\t*/Auth-Initial:\n\t[success=end default=ignore]\tpam_unix.so\tnodelay\t/g' /usr/share/pam-configs/unix &>/dev/null
        echo "✔ nodelay parameteer added to Unix PAM."

        echo "❐ Configuring PAM..."
        ### THIS CONFLICTS ### @richardev
        # sudo DEBIAN_FRONTEND=noninteractive pam-auth-update --force &>/dev/null
        # sudo pam-auth-update --package &>/dev/null
        ######################
        grep -Eo 'auth\s+\[success=([0-9])' /etc/pam.d/common-auth | while read -r line ; do
        current_index=$(echo "$line" | grep '[0-9]' -o)
        new_index=$(expr $current_index + 1)
        new_line="${line::-1}$new_index"
        sed -i "s/auth\s*\t*\[success=$current_index/auth\t\[success=$new_index/" /etc/pam.d/common-auth
        done
        sed -i '/auth\s*\t*\[success=2/a auth\t[success=1 default=ignore]\tpam_exec.so seteuid debug /usr/local/bin/ppnfc_pam.py' /etc/pam.d/common-auth
        echo "✔ Done configuring PAM."
        
        display_size=$(xdpyinfo | grep dimensions | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
        display_width=$(cut -d'x' -f1 <<<"$display_size")
        display_height=$(cut -d'x' -f2 <<<"$display_size")
        popup_width=400
        popup_height=150
        posx=$(( ($display_width/2) - (popup_width/2) ))
        posy=$(( ($display_height/2) - (popup_height/2) ))

        echo "✔ Scheduled device reboot in 5min!"
        kdialog --geometry $popup_width\x$popup_height+$posx+$posy --title "BKUS | Uzmanību!" --error "Administrātors atjaunināja jūsu darbstaciju.\nJūsu ierīce tiks restartēta 3 minūšu laikā.\nLūdzu saglabājiet visu nepieciešamo.\nJa esat gatavi, varat pašrocīgi restartēt darbstaciju." &>/dev/null
        ( sleep 180 ; reboot ) & 
    fi
fi

printf "\n\n          ✔ PAMpy NFC INSTALLED ✔\n\n"
