**As any other Powershell file, you might need to unlock this one before opening through RMB > Properties > Unlock.**

In multidomain environment, in rare occasions, there might be a need to create local, on-premises only users for external/remote domain users.
For example, we can have hgevorgyan@studio.lan user on a remote Studio.lan DC that needs to be synchronized with hgevorgyan (or any other user) on Sakurada.lan.
I beg you to not try to educate me on domain federative/trust relationship matters - this script might be needed for WHATEVER reasons that are out there in cursed scenarios like the one I described above.

Essentially, the script does the following logical procedures:
1. Looks up the descriptions of all the users of $SearchBase variable that contains OU's DistinguishedName
2. Wraps all the users that contain $UserDescription variable in their descriptions into $Users table
3. Takes the Office attribute (that should contain remote DC SamAccountName attribute of the user) and requests the Name, SamAccountName, Title, Department and Enabled attributes of the user under that SamAccountName
4. If the user is enabled remotely, enables it locally and synchronizes the Title and Department attributes. If the user is disabled remotely, disables him locally.

There are also "emergency brakes" in case of errors:
1. If the user isn't found on the remote domain, it's being disabled locally
2. In case of any other errors, script shuts down immediately and (if SMTP connected) sends alerts.

Any user can be linked to any other user through the Office, or really any other attribute.

It can be run manually or headless through the Task Scheduler.

The code is fairly simple and relatively small, the design can be considered borderline intuitive.

As an EXTREMELY NICE TO HAVE, it logs separately every run into a C:\by3142\FedUserSynchronizer folder, logs all the NEWLY enabled/disabled users, and sends mentioned directory updates to email.
