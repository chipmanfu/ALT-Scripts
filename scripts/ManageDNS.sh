#!/bin/bash
# Written by Chip McElvain 
# Manages Domain name registration
# NOTE: Set up ssh keys between the primary range DNS server and this redirector 
# before this will work.
rootDNS="198.41.0.4"
# Set variable names to add color codes to menu displays.
white="\e[1;37m"
ltblue="\e[1;36m"
ltgray="\e[0;37m"
red="\e[1;31m"
green="\e[1;32m"
whiteonblue="\e[5;37;44m"
yellow="\e[1;33m"
default="\e[0m"

# Check for network connectivity to the primary DNS server.
ping -c 1 $rootDNS 1>/dev/null

if [[ $? -ne 0 ]]
then
  clear
  echo -e "\n\t\t\t$red ####  ERRROR  ####"
  echo -e "\t$ltgray Can't reach the primary DNS server at $rootDNS"
  echo -e "\t Check your IPs\n$default"
  exit 0;
fi

# set conf file location
TempDNSconf="/tmp/tmpDNS.txt"
DNSconf="/root/OPFOR-DNS.txt"
CurDNSInfo="/tmp/CurDNSinfo.txt"
# Set variables
random=0
bannertitle="DNS Management Menu"
# Header for all menu items, clears the terminal, adds a banner.
MenuBanner()
{
  clear
  printf "\n\t$ltblue %-60s %8s\n"  "$bannertitle" "<b>-Back"
  printf "\t$ltblue %60s %8s\n"  "" "<q>-Quit"
}

FormatOptions()
{
  local count="$1"
  local title="$2"
  local dnsname="$3"
  printf "\t$ltblue%3b )$white %-15b $green%-40b\n" "$count" "$title" "$dnsname"
}

InputError()
{
  echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
}

UserQuit()
{
  echo -e "$default";if [[ -f "$TempDNSconf" ]]; then rm $TempDNSconf; fi; exit 0
}

DNSMenu()
{
  MenuBanner
  echo -e "\n\t$ltblue What would you like to do?"
  FormatOptions 1 "Add DNS records"
  FormatOptions 2 "Delete DNS records"
  FormatOptions 3 "View DNS records"
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read answer 
  case $answer in 
    1)  AddDNSMenu;;
    2)  DeleteDNSMenu;;
    3)  ViewDNSMenu;;
    b|B) DNSMenu;;
    q|Q) UserQuit;;
    *) InputError
       DNSMenu;;
  esac
}
GetDNSInfo()
{
  # Get DNS information for the primary DNS server
  ssh $rootDNS 'cd /etc/bind/OPFOR; grep -Eo "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" * | uniq | sed "s/db.//" | sed "s/\:/ /"' > /tmp/IPinfo
  ssh $rootDNS 'cd /etc/bind/OPFOR; grep -Eo "OPFOR[-0-9A-Za-z]{0,40}" * | sed "s/db.//" | sed "s/\:/ /"' > /tmp/taginfo
  awk 'FNR==NR{a[$1]=$2 FS $3;next} $1 in a {print $0, a[$1]}' /tmp/taginfo /tmp/IPinfo | sort -k 3 > $CurDNSInfo
  usertags=`cat $CurDNSInfo | cut -d " " -f 3 | sort -u`
}

ViewDNSMenu()
{
  GetDNSInfo
  MenuBanner
  echo -e "\n\tTo view registered OPFOR DNS records, select from the options below"
  FormatOptions 1 "View all OPFOR DNS records"
  count=2
  for usertag in $usertags
  do 
    FormatOptions "$count" "tagged with ${yellow}$usertag$white"
    let count++
    if [[ $count == 21 ]]; then break; fi
  done
  echo -en "\n\t$ltblue Enter a Selection: $white"
  read answer
  case $answer in 
    b|B) DNSMenu;;
    q|Q) UserQuit;;
      *) if (( $answer >= 1 && $answer < $count)) 2>/dev/null; then
           clear
           if (( $answer == 1 )); then
             cat $CurDNSInfo
	     echo "Hit return to continue"
             read doesntmatter
	     ViewDNSMenu 
           else
             offset=`expr $answer - 1`
             user=`echo $usertags | cut -d" " -f$offset`
             grep $user $CurDNSInfo > /tmp/userdns.txt
             cat /tmp/userdns.txt
	     echo "Hit return to continue"
             read doesntmatter
             rm /tmp/userdns.txt
             ViewDNSMenu
           fi
         else
           InputError
           ViewDNSMenu
         fi;;
  esac
}
DeleteDNSMenu()
{
  GetDNSInfo
  MenuBanner
  echo -e "\n\t$yellow Note: DNS records are tagged with the username you created when you made them."  
  echo -e "\tSelecting option 2 will delete ones you previously created using that username"
  echo -e "\tWarning, if someone else created records using this same username,"
  echo -e "\tthey will get delete too\n"
  echo -e "\t$ltblue Which DNS records would you like to delete?"
  FormatOptions 1 "${red}All$white OPFOR DNS Records"
  count=2
  for usertag in $usertags
  do 
    FormatOptions "$count" "tagged by ${yellow}$usertag$white"
    let count++
    if [[ $count == 21 ]]; then break;fi
  done
  echo -en "\n\t$ltblue Enter a Selection: $white"
  read answer
  case $answer in
    b|B) DNSMenu;;
    q|Q) UserQuit;;
    *) if (( $answer >= 1 && $answer <= $count)) 2>/dev/null; then
         if (( $answer == 1 )); then
           delopt="all" 
         else
           offset=`expr $answer - 1`
           user=`echo $usertags | cut -d" " -f$offset`
           delopt=$user
         fi
         DeleteDNS
       else
         InputError
	 DeleteDNSMenu
       fi;;
  esac
}

DeleteDNS()
{
  MenuBanner
  if [[ $delopt == "all" ]]; then
    echo -e "\n\t$yellow Warning!!! This will delete$red ALL$yellow Red Team DNS records.\n"
    echo -e "\t$ltblue Are you absolutely sure this is what you want to do?"
  else 
    echo -e "\n\t$yellow Warning! This will delete all DNS records for $delopt"
    echo -e "\n\t$ltblue Are you sure you want to delete all$yellow $delopt$ltblue Red Team DNS records?"  
  fi
  echo -en "\t$ltblue Enter y to continue $default "
  read answer 
  case $answer in
     y|Y|yes|YES|Yes) 
       clear
       if [[ $delopt == "all" ]]; then
         echo -e "\n\t$red YOUR ARE DELETING ALL OPFOR DNS RECORDS!! Are you sure about this?"
         echo -e "\n\t$yellow Deleting in 30 seconds, hit ctrl+C to abort$default"
         sleep 30
         ssh $rootDNS '/root/scripts/delete-REDTEAM-DNS.sh'
         echo -e "\n\t$green All Red Team DNS has been deleted, I hope you really wanted to do this.$default"
       else
	 echo -e "\n\t$ltblue Deleting DNS records for$yellow $delopt$ltblue in 10 seconds, hit ctrl+c to abort$default"
	 sleep 10
         ssh $rootDNS "/root/scripts/delete-REDTEAM-DNS.sh $delopt"
         echo -e "\n\t$green All Red Team DNS tagged with $delopt have been deleted," 
         echo -e "\t I hope you really wanted to do this.$default"
       fi;;
     b|B) DeleteDNSMenu;;
     q|Q) UserQuit;;
     *) InputError
        DeleteDNS;;
   esac
   
}
  
AddDNSMenu()
{
  GetDNSInfo
  MenuBanner
  echo -e "\n\t$ltblue How would you like to assign domain names?"
  FormatOptions 1 "Manually create domain name/s."
  FormatOptions 2 "Use randomly generated one/s."
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read answer
  case $answer in
    1)  ManualDNS;;
    2)  random=1; AddTagMenu;;
    b|B) DNSMenu;;
    q|Q) UserQuit;;
    *) InputError
       AddDNSMenu;;
  esac
}
AddTagMenu()
{ 
  MenuBanner
  echo -e "\n\t$ltblue Enter a tag to be able to identify your DNS records"
  echo -e "\t The tag will automatically be prepended with OPFOR-"
  echo -e "\t Best Practice: Use your FirstName and use.  For example,"
  echo -e "\t\t  $white Chad-DecScrim  or  Joe-Testing $ltblue" 
  echo -e "\t If you decide to add additional DNS Records for the same purpose"
  echo -e "\t then re-use the same tag"
  echo -ne "\n\t  Enter a Tag here: $white"
  read answer
  case $answer in
    b|B) DNSMenu;;
    q|Q) UserQuit;;
      *) Tagin=$answer;;
  esac
  ExecAndValidate
}

ManualDNS()
{
  MenuBanner
  intname="eth0"
  iplist=`ip a | grep $intname | grep inet | awk '{print $2}' | cut -d/ -f1`
  numip=`echo "$iplist" | wc -l`
  if [[ $numip == 1 ]]; then
    echo -e "\n\t$ltblue Your Current IP is $green $iplist"
    echo -e "\n\t$ltblue Please set the Fully Qualified Domain Name you would like to use"
    echo -ne "\n\t$ltblue Here:"
    read DNSin
    regexfqn="(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+\.(?:[a-z]{2,})$)"
    if [[ `echo $DNSin | grep -P $regexfqn` ]]; then
      ## Check if dns is already registered
      if grep -q "$DNSin" $CurDNSInfo; then
        echo "$DNSin is already registred, please try again."; sleep 2
        ManualDNS
      else
        #Remove any previously set FQDN for the IP selected.
        sed -i "/$iplist/d" $TempDNSconf
        #Add new FQDN
        lowercaseDNS=`echo $DNSin | tr '[:upper:]' '[:lower:]'`
        echo "$lowercaseDNS,$iplist" >> $TempDNSconf
        AddTagMenu
      fi
    else
      echo "$DNSin is not a valid FQDN, please try again."; sleep 2
      ManualDNS
    fi
  else  
    echo -e "\n\t$ltblue You currently have multiple IP's, you can set manual FQDNs"
    echo -e "\t$ltblue for each one, select an IP from the list to set a FQDN for that"
    echo -e "\t$ltblue IP, once set it will bring you back to this menu, select D for"
    echo -e "\t$ltblue done when you're finished adding FQDN's to IPs\n"
    count=1
    for ip in $iplist 
    do
      dnsadded=`grep $ip $TempDNSconf 2>/dev/null | cut -d, -f1`	
      if [[ ! -z $dnsadded ]]; then
        FormatOptions "$count" "$ip" "$dnsadded"
      else
        FormatOptions "$count" "$ip"
      fi
      let count++
    done
    FormatOptions "c" "Clear all"
    FormatOptions "d" "Done"
    echo -ne "\n\t$ltblue Enter a Selection Here: $white"
    read answer
    case $answer in
      b|B) DNSMenu;;
      q|Q) UserQuit;;
      c|C) cp /dev/null $TempDNSconf; ManualDNS;; 
      d|D) AddTagMenu;;
      *) if [[ $answer -ge 1 ]] && [[ $answer -le $numip ]]; then
           IPselected=`echo "$iplist" | sed -n ${answer}p`
           DNSentry
         else 
           InputError
           ManualDNS
         fi;;
    esac
  fi
}

DNSentry()
{
  MenuBanner
  domainin=`grep $IPselected $TempDNSconf 2>/dev/null | cut -d, -f1`	
  if [[ $domainin != "" ]]; then
    echo -e "\n\t$ltblue DNS already assigned as $green $domainin"
    echo -e "\t$ltblue This will replace it, if this isn't what you want hit B to go back"
  fi
  echo -e "\n\t$ltblue Your Current IP is $green $IPselected"
  echo -e "\n\t$ltblue Please set the Fully Qualified Domain Name you would like to use"
  echo -ne "\n\t$ltblue Here:$white "
  read DNSin
  if [[ $DNSin == b ]] || [[ $DNSin == B ]]; then ManualDNS; fi
  if [[ $DNSin == q ]] || [[ $DNSin == Q ]]; then exit 0; fi
  regexfqn="(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)"
  if [[ `echo $DNSin | grep -P $regexfqn` ]]; then
    if grep -q -i "$DNSin" $CurDNSInfo; then
      echo "$DNSin is already registered, please try again."; sleep 2
      ManualDNS
    else
      #Remove any previously set FQDN for the IP selected.
      sed -i "/$IPselected/d" $TempDNSconf
      #Add new FQDN
      lowercaseDNS=`echo $DNSin | tr '[:upper:]' '[:lower:]'`
      echo "$lowercaseDNS,$IPselected" >> $TempDNSconf
      ManualDNS
    fi
  else
    echo -e "\t\t$red $DNSin is not a valid FQDN, please try again."; sleep 2
    DNSentry
  fi
}

ExecAndValidate()
{
  clear
  if [[ $random == 1 ]]; then 
    echo -e "\n\t$ltblue This will assign new random domains to this redirectors IP's."
    echo -e "\t If you already ran this, you will still have the old domains assigned as well as a new list"
    echo -e "\t However this will overwrite your existing list at $DNSconf"
    echo -e "\t If this is what you want to do, you should make a copy of the"
    echo -e "\t current $DNSconf before running this."
    echo -e "\t If this is the first time, then no worries\n"
    echo -en "\t Are you sure you want to continue <y or n>: $default " 
    read ans
    case $ans in
      y|Y|yes|YES|Yes) ;;
      n|N|no|NO|No) DNSMenu; exit;;
      q|Q) UserQuit;;
      b|B) DNSMenu; exit;;
      *) InputError; ExecAndValidate;;
    esac
    #Make sure the IPList.txt file doesn't already have a tag
    sed -i '/# Tag:/d' /root/scripts/IPList.txt
    #add Tag
    echo "# Tag:$Tagin" >> /root/scripts/IPList.txt
    scp /root/scripts/IPList.txt $rootDNS:/root/scripts/autoredirector/iplist.txt
    ssh $rootDNS '/root/scripts/autoredirector/makednsfile.sh /root/scripts/autoredirector/iplist.txt'
    ssh $rootDNS '/root/scripts/add-REDTEAM-DNS.sh /root/scripts/autoredirector/dnsfile.txt'
    scp $rootDNS:/root/scripts/autoredirector/dnsfile.txt /root/OPFOR-DNS.txt
    ssh $rootDNS 'rm /root/scripts/autoredirector/dnsfile.txt'
    echo -e "$green  DNS Records assigned to the redirector IPs."  
    echo -e "$green  See $DNSconf for a list of your domains. $default\n\n"
  else
    if [ ! -s $TempDNSconf ]
    then
      echo -e "\n\t$yellow No manually created DNS records found, script is exiting $default\n" 
      exit 0;
    fi
    # Tag the DNS file with the servers hostname
    echo "# Tag:$Tagin" >> $TempDNSconf
    mv $TempDNSconf $DNSconf
    scp $DNSconf $rootDNS:/root/scripts/OPFOR-DNS.txt
    echo -e "$ltblue"
    ssh $rootDNS '/root/scripts/add-REDTEAM-DNS.sh /root/scripts/OPFOR-DNS.txt'
    echo -e "$default"
  fi
}
DNSMenu
