![alt text](https://github.com/Sdelsaz/PIN-for-Admin/blob/main/icon.png?raw=true)

# PIN-for-Admin

This script is based on Laurent Pertois' Temp Admin script:

https://github.com/laurentpertois/Temp-Admin

This script allows users to request temporary admin privileges. When the time is up it demotes the user and any other accounts that did not originally have admin privileges. The privileges are only granted if the user is able to provide a random PIN that the script generates and sends to an attribute of choice in Jamf Pro.

The following can be customized:
  
- The amount of time the user gets admin privileges for
- The attribute to populate the PIN with in Jamf Pro
- The number of PIN attempts allowed.
- The length of the PIN


 Parameters:

- $4= Amount of time in minutes
- $5= Attribute to be used for the PIN
- $6= Maximum number of attempts
- $7= Number of characters/PIN length

 You can set the amount of time for which they have this privilege in Minutes as Parameter 4.  If no amount of time is set, the default is 10 minutes.
 
 A window will show them the amount of time left, if they close it the script will still execute
 
 After the time is elapsed, their privileges are removed. Any new account that is admin is also
 demoted except the accounts that were admin before the execution of the script.

 You can use one of the following attributes to popiulate with a random PIN in Jamf Pro. Make sure to include the Hyphen and choose an attribute that isn't actually used.

 - -assetTag
 - -endUsername 		
 - -realname
 - -email
 - -position
 - -building
 - -department
 - -phone
 - -room

 You can set the attribute to be used in Parameter 5.  If no attribute is set, the default is the assetTag.

 You can set the maximum amount of attempts in Parameter 6.  If no value is set, the default is 3.

 You can set the Length of the PIN in Parameter 7.  If no value is set, the default is 5 characters.
 
 An icon you can use for the policy in Self Service is also provided.

 # Pre-requirements:

 A PPPC (Privacy Preferences Policy Control), aka TCC, configuration profile is required now to give the atrun command access to the disk. 
 An example is  provided.

