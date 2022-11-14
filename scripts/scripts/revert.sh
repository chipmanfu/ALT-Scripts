#!/bin/bash
# Written by Chip McElvain
# Set redteam server back to defaults.

# Clears terminal for output messages
clear

# Set variable names to add color codes to menu displays.
white="\e[1;37m"
ltblue="\e[1;36m"
ltgray="\e[0;37m"
red="\e[1;31m"
green="\e[1;32m"
whiteonblue="\e[5;37;44m"
yellow="\e[1;33m"
default="\e[0m"

# Check to make sure they really want to do this.
echo -e "\n\t$ltblue This will revert the redirector back to defaults.\n"
echo -en "\tAre you sure you want to do this?(yes/no) $default"
read ans
case $ans in
  y|Y|yes|Yes|YES) 
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -t nat -F
    service haproxy stop
    service nginx stop
    service apache2 stop
    killall java >/dev/null 2>&1
    lsof -n -i4TCP:443 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
    lsof -n -i4TCP:80 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
    lsof -n -i4TCP:53 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
    lsof -n -i4UDP:53 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
    # deletes interface configuration and clears the routing table
    if test -f /etc/nginx/nginx.conf.org; then
	cp /etc/nginx/nginx.conf.org /etc/nginx/nginx.conf
    fi
    hostnamectl set-hostname rts
    # reset interfaces
    echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces
    echo -e "\nauto eth0\niface eth0 inet static" >> /etc/network/interfaces
    echo -e "     address 100.1.1.1" >> /etc/network/interfaces
    echo -e "\nauto eth1\niface eth1 inet dhcp" >> /etc/network/interfaces 
    ip addr flush eth0
    ip route flush table main 
    service networking restart
    echo -e "\n\t $green The redirector has been revert back to orginal configuration\n";;
  *)
    echo -e "\n\t $ltgray Revert Aborted.. Script exiting$default\n" 
    exit 0;;  
esac
echo -e "$default"
exec bash
