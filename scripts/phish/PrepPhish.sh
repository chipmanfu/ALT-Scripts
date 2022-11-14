#!/bin/bash
## VARIABLES
conf="/etc/postfix/main.cf"

#add some color, cuz why not.
default="\e[0m"
red="\e[1;31m"
green="\e[1;32m"
yellow="\e[1;33m"
ltblue="\e[1;36m"
white="\e[1;37m"

UsageMessage()
{
  echo -e "\n$green Usage: PrepPhish.sh <yourdomain>\n"
  echo -e "$yellow<yourdomain>$ltblue - should be the domain of our phish user, ex. iliketurtles.com"
  echo -e "\tThis domain has to be registered with an MX record to pass some domain sender checks."
  echo -e "\tYou can register the domain using the ManageDNS.sh if you set the IP/s for this using buildredteam.sh"
  echo -e "\tOr by using RegisterDNS.sh$white"
}

if [[ -z $1 ]]; then
  UsageMessage
  exit
fi
fqdn=$1
if (nslookup -type=mx $fqdn | grep -q "No answer"); then
  echo -e "\n$red ERROR: the domain entered can't resolve the MX record.  See below"
  nslookup -type=mx $fqdn  
else
  echo -e "\n$green Your domain of $fqdn successfully resolved its MX record! Setting up phishing now$default"
  service postfix stop
  sed -i '/^myorigin/d' $conf
  sed -i '/^myhostname/d' $conf
  sed -i '/^smtpd_banner/d' $conf
  sed -i '/^mydestination/d' $conf
  sed -i '/^virtual_alias_maps/d' $conf
  echo "myhostname=$fqdn" >> $conf
  echo "myorigin=/etc/mailname" >> $conf
  echo "smtpd_banner= \$myhostname Microsoft ESMTP Mail" >> $conf
  echo "mydestination= \$myhostname,localhost" >> $conf
  echo "virtual_alias_maps=hash:/etc/postfix/virtual_alias" >> $conf
  echo $fqdn > /etc/mailname
  echo "mailer-daemon: postmaster" > /etc/aliases
  echo "admin@$fqdn admin" > /etc/postfix/virtual_alias
  postmap /etc/postfix/virtual_alias
  newaliases
  service postfix start
  echo -e "\n$green Set up is complete, happy phishing!$default"
fi


