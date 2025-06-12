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
# This script is based on Laurent Pertois' Temp Admin script:
#
# https://github.com/laurentpertois/Temp-Admin 
#
# The script will generate a random PIN, send it to the Jamf Pro Inventory and prompt the user for the PIN.
# The following can be customized:
# - The amount of time the user gets Admin Privileges for
# - The number of PIN attempts allowed.
# - The length of the PIN
# 
#
# Parameters:
#
# $4= Amount of time in minutes
# $5= Maximum number of attempts
# $6= Number of characters/PIN length
#
# You can set the amount of time for which they have this privilege in Minutes as Parameter 4
# If not amount of time is set, the default is 10 minutes.
# 
# A window will show them the amount of time left, if they close it the script will still execute
# 
# After the time is elapsed, their privileges are removed. Any new account that is admin is also
# demoted except the accounts that were admin before the execution of the script.
#
# You can set the maximum amount of attempts in Parameter 5
# If no value is set, the default is 3
#
# You can set the Length of the PIN in Parameter 6
# If no value is set, the default is 5 characters
#
# Created by: Sebastien Del Saz Alvarez
# Updated On: 2022-11-22 to random PIN creation
# Updated On: 2023-04-22 to allow to set the maximum number of attempts and the PIN Length
# Updated On: 2024-06-20 to use a hidden local file to store the PIN. This avoids potential issues with recyclinbg existing attributes.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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

# Generate a random PIN and populate the attribute of hidden file with the value

PIN=$(printf '%0'$PINLength'd\n' $((1 + RANDOM % 1000000)))

# write PIN to hidden file

touch /usr/local/.PIN.txt

echo $PIN > /usr/local/.PIN.txt

# Update inventory to populat ethe Extension Attribute

jamf recon

# Delete PIN

> /usr/local/.PIN.txt

while  [[ $UserPin != $PIN ]] && [[ $Attempt -lt $MaxAttempt ]]

do
		
# Request PIN from enduser
Attempt=$(( Attempt +1 ))
echo "$Attempt Attempt out of $MaxAttempt"
		
read -r -d '' applescriptCode <<'EOF'
set UserPin to text returned of (display dialog "Please enter the PIN Provided by your Service Desk" default answer "" with title "Admin rights")
return UserPin
EOF
		
UserPin=$(osascript -e "$applescriptCode")
		
if [ "$?" != "0" ] ; then
echo "User aborted. Exiting..."
exit 0
fi
		
done

if [[ "$UserPin" == "$PIN" ]]; then

echo "Correct PIN Provided, granting Temporary Admin Rights"
		
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
			
# Makes the user an admin
/usr/sbin/dseditgroup -o edit -a "$USERNAME" -t user admin
logger "Elevating $USERNAME."
			
# Path to Jamf Helper
JAMFHELPERPATH="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
			
# Displays a window showing how much time is left as an admin using Jamf Helper	
			"$JAMFHELPERPATH" -windowType utility \
			-windowPosition ur \
			-title "Elevate User Account" \
			-heading "Temporary Admin Rights Granted" \
			-alignHeading middle \
			-description "Please perform required administrative tasks" \
			-alignDescription natural \
			-icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/UnlockedIcon.icns" \
			-iconSize 36 \
			-button1 "Done" \
			-defaultButton 1 \
			-timeout "$TEMPSECONDS" \
			-countdown \
			-countdownPrompt "Admin Rights will be revoked in " \
			-alignCountdown center
			
# Writes in logs when it's done
logger "Elevation complete."
exit 0
fi
		
# If user is already an admin, we write this in logs, tell the user and then quit
logger "User already has elevated privileges."
osascript -e "display dialog \"You already have elevated privileges \" buttons \"OK\" with icon caution"
		
fi


if [[ "$UserPin" != "$PIN" ]]; then
	
echo "Wrong PIN provided $MaxAttempt times"
	
osascript -e "display dialog \"Incorrect PIN. Please contact your Servicedesk to obtain a PIN\""
	
fi

exit 0
