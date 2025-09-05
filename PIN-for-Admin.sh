#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# The script will generate a random PIN, and prompt the user for the PIN. An Extension Attribute is used to populate the PIN in the Jamf Pro Inventory
#
# Parameters:
#
# $4= Amount of time in minutes
# $5= Maximum number of attempts
# $6= Number of characters/PIN length
# $7= Organisation name
# $8= Path to a custom icon
#
# This script is based on Laurent Pertois' Temp Admin script:
# https://github.com/laurentpertois/Temp-Admin 
#
# This script uses Bart Reardon's swiftDialog for user dialogs:
# https://github.com/bartreardon/swiftDialog
#
# Created by: Sebastien Del Saz Alvarez
# Updated On: 2022-11-22 to random PIN creation
# Updated On: 2023-04-22 to allow to set the maximum number of attempts and the PIN Length
# Updated On: 2024-06-20 to use a hidden local file to store the PIN. This avoids potential issues with recycling existing attributes.
# Updated On: 2025-07-25 to use SwiftDialog for the prompts and add custom branding options
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Check if Swift Dialog is installed. if not, Install it
logger "Checking if SwiftDialog is installed"
if [[ -e "/usr/local/bin/dialog" ]]
then
logger "SwiftDialog is already installed"
else
logger "SwiftDialog Not installed, downloading and installing"
/usr/bin/curl https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.5/dialog-2.5.5-4802.pkg -L -o /tmp/dialog-2.5.5-4802.pkg 
cd /tmp
/usr/sbin/installer -pkg dialog-2.5.5-4802.pkg -target /
fi

# Variables:
# Check if there is a value passed as $4 for the number of minutes, if not, defaults to 10
if [ -z "$4" ]; then
	TEMPMINUTES=10
else
	
# Check if the value passed as $4 for the number of minutes is a positive numeric number 
# without any extra characters (i.e. 10, not +10 or -10), if not, defaults to 10
if [[ "$4" =~ [^0-9]+ ]] ; then
	TEMPMINUTES=10
else
	TEMPMINUTES="$4"
fi
fi

# Check if there is a value passed as $5 for the maximum number of attempts, if not, defaults to 3
if [ -z "$5" ]; then
	MaxAttempt="3"	
else
	MaxAttempt="$5"	
fi

# Check if there is a value passed as $6 for the PIN Lenth, if not, defaults to 5 characters
if [ -z "$6" ]; then
	PINLength="5"	
else
	PINLength="$6"	
fi

# Check if there is a value passed as $7 for the Organisation Name, if not, set default title
if [ -z "$7" ]; then
	OrgName="PIN for Admin"	
else
	OrgName="$7"	
fi

# Check if there is a value passed as $8 for the icon, if not, set default icon
if [ -z "$8" ]; then
	Icon="https://i.imgur.com/vJrHrFJ.png"	
else
Icon="$8"	
fi

# Fonts
MessageFont="size=20,name=PTSans-Regular"
TitleFont="weight=bold,size=30,name=PTSans-Regular"

# Prompts
PINPrompt()
{
UserPin=$(dialog --small --title "$OrgName" --titlefont "$TitleFont" --message "Please enter the PIN provided by IT." --messagefont "$MessageFont" --icon "$Icon" --alignment "left" --textfield "PIN","secure" : true --button2 --alignment "left" --height "30%")
if [ $? == 0 ]
then
UserPin=$(echo "$UserPin" | awk -F ': ' '{print $2}')
else
echo "User cancelled"
exit 0
fi
}

IncorrectPINPrompt()
{
	dialog --small --title "$OrgName" --titlefont "$TitleFont" --message "Incorrect PIN provided too many times.\n\n Please contact IT to obtain a PIN." --icon "$Icon" --messagefont "$MessageFont" --button2 --alignment "left" --height "30%" --witdh "40%"
}

AlreadyAdminPrompt()
{
	dialog -s --title "$OrgName" --titlefont "$TitleFont" --message "You already have elevated privileges." --icon "$Icon" --messagefont "$MessageFont" --button2 --alignment "left" --height "30%" --witdh "40%"
}

ElevationCompletePrompt()
{
	dialog -s --title "$OrgName" --titlefont "$TitleF0nt" --message "You now have temporary Administrator Privileges.  \n  \nYou can close this window without affecting your temporary elevation." --icon "$Icon" --messagefont "$MessageFont" --timer $TEMPSECONDS --button1text "Close" --alignment "left" --height "40%" --witdh "40%" --moveable --position "topright"
}

# Generate a random PIN and populate the attribute of hidden file with the value
PIN=$(printf '%0'$PINLength'd\n' $((1 + RANDOM % 1000000)))

# write PIN to hidden file
touch /usr/local/.PIN.txt

echo $PIN > /usr/local/.PIN.txt

# Update inventory to populate the Extension Attribute
jamf recon

# Delete PIN
> /usr/local/.PIN.txt

while  [[ $UserPin != $PIN ]] && [[ $Attempt -lt $MaxAttempt ]]

do
# Request PIN from enduser
Attempt=$(( Attempt +1 ))
logger "$Attempt Attempt out of $MaxAttempt"

PINPrompt

done

if [[ "$UserPin" == "$PIN" ]]; then

logger "Correct PIN Provided, granting Temporary Admin Rights"
		
# Get username of current logged in user
USERNAME=$(/bin/echo 'show State:/Users/ConsoleUser' | /usr/sbin/scutil | /usr/bin/awk '/Name / { print $3 }')
		
# Calculates the number of seconds
TEMPSECONDS=$((TEMPMINUTES * 60))
		
# Writes in logs
logger "Checking privileges for $USERNAME."
		
# Checks if account is already an admin or not
MEMBERSHIP=$(dsmemberutil checkmembership -U "$USERNAME" -G admin)
		
if [ "$MEMBERSHIP" == "user is not a member of the group" ]; then
			
# Checks if atrun is launched or not (to disable admin privileges after the defined amount of time)
if ! launchctl list|grep -q com.apple.atrun; then launchctl load -w /System/Library/LaunchDaemons/com.apple.atrun.plist; fi
			
# Uses at to execute the cleaning script after the defined amount of time
# Be careful, it can take some time to execute and be delayed under heavy load
echo "#!/bin/bash
# For any user with UID >= 501 remove admin privileges except if they existed prior the execution of the script
ADMINMEMBERS=($(dscacheutil -q group -a name admin | grep -e '^users:' | sed -e 's/users: //' -e 's/ $//'))
NEWADMINMEMBERS=(\$(dscacheutil -q group -a name admin | grep -e '^users:' | sed -e 's/users: //'))
for user in \"\${NEWADMINMEMBERS[@]}\";do
# Checks if user is whitelisted or not
WHITELISTED=\$(echo \"\${ADMINMEMBERS[@]}\"  | grep -c \"\$user\")
if [ \$WHITELISTED -gt 0 ]; then
			
logger \"\$user is whitelisted\"
			
else
		
# If not whitelisted, then removes admin privileges
/usr/sbin/dseditgroup -o edit -d \$user -t user admin
fi	
done
exit $?" | at -t "$(date -v+"$TEMPSECONDS"S "+%Y%m%d%H%M.%S")"
			
# Make the user an admin
/usr/sbin/dseditgroup -o edit -a "$USERNAME" -t user admin
logger "Elevating $USERNAME."
			
# Display a window showing how much time is left as an admin using Jamf Helper	
ElevationCompletePrompt

# Writes in logs when it's done
logger "Elevation complete."
exit 0
fi
		
# If user is already an admin, we write this in logs, tell the user and then quit
logger "User already has elevated privileges."
AlreadyAdminPrompt
		
fi

if [[ "$UserPin" != "$PIN" ]]; then

logger "Incorrect PIN Provided $MaxAttempt times"
IncorrectPINPrompt
	
fi

exit 0
