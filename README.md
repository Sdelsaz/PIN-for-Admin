![alt text](https://github.com/Sdelsaz/PIN-for-Admin/blob/main/icon.png?raw=true)

# PIN-for-Admin

This script is based on Laurent Pertois' Temp Admin script:

https://github.com/laurentpertois/Temp-Admin

This script uses Bart Reardon's swiftDialog for user communication:

https://github.com/bartreardon/swiftDialog

This script allows users to request temporary administrator privileges. When the time is up it demotes the user and any other accounts that did not originally have administtrator privileges. The privileges are only granted if the user is able to provide a random PIN that the script generates. An extension atribute is used to collect the PIN in Jamf pro. If administrator privileges are granted, a window will show the amount of time left. The user can close this window without affecting the temporary elevation.

![alt text](https://github.com/Sdelsaz/PIN-for-Admin/blob/main/Images/PinPrompt.png?raw=true)

![alt text](https://github.com/Sdelsaz/PIN-for-Admin/blob/main/Images/AdminConfirmation.png?raw=true)


### Parameters:

The following can be customized:

$4= Amount of time in minutes: You can set the amount of time for which they have this privilege in minutes as Parameter 4.  If no amount of time is set, the default is 10 minutes.

$5= Maximum number of attempts: You can set the maximum amount of attempts in Parameter 5.  If no value is set, the default is 3.

$6= Number of characters/PIN length: You can set the Length of the PIN in Parameter 6.  If no value is set, the default is 5 characters.

$7= Organisation name: You can set the Organisation Name in Paremeter 7. If no Value is set, "Pin for Admin" is used for the title.

$8= Path/Link to a custom icon: You can provide the path or link to a custom icon in Paremeter 8. If no Value is set, the default icon is used.

### Pre-requirements:

A PPPC (Privacy Preferences Policy Control), aka TCC, configuration profile is required now to give the atrun command access to the disk. 
An example is provided. IMPORTANT: This profile is needed for the demotion back to standard user.

An Extension Attribute is used to collect the PIN in Jamf pro. The Extension Attribute is provided.
