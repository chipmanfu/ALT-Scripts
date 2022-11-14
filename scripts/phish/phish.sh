#!/bin/bash
# Example phishing script.

# set .muttrc file
echo 'set edit_headers=yes' > /root/.muttrc 
echo 'set from = "No-Reply@minidesktopgames.com"' >> /root/.muttrc
echo 'set realname = "MiniDesktopGames"' >> /root/.muttrc

# NOTE: you need to make an email body message and save it as body.txt in the root folder
# NOTE: if you had an attachment then add that to the /root/scripts/phish directory.
echo "" | mutt -s "Everyone needs a Doom break now and then" -i /root/scripts/phish/body.txt -- nickolas.guerra@finco.com
