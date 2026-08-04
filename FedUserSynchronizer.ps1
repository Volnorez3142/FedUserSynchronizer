#THIS BLOCK ELEVATES THE STARTED PS SESSION TO ADMIN (NEEDED FOR MANUAL RUN)
#if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
# if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
#  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
#  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
#  Exit
# }
#}

#CHECKING AND CREATING THE NECESSARY DIRECTORIES, STARTING THE LOG
$test3142dir = Test-Path C:\by3142
$fedusersyncdir = Test-Path C:\by3142\FedUserSynchronizer
if (-not $test3142dir) {
    Write-Host "No C:\by3142 directory found!" -ForegroundColor Red
    Write-Host "Creating C:\by3142 directory..." -ForegroundColor DarkGreen
    New-Item -Path "c:\" -Name "by3142" -ItemType "directory"
    Write-Host "Creating C:\by3142\FedUserSynchronizer directory..." -ForegroundColor DarkGreen
    New-Item -Path "c:\by3142" -Name "FedUserSynchronizer" -ItemType "directory"
} elseif (-not $fedusersyncdir) {
    Write-Host "No C:\by3142\FedUserSynchronizer directory found!" -ForegroundColor Red
    Write-Host "Creating C:\by3142\FedUserSynchronizer directory..." -ForegroundColor DarkGreen
    New-Item -Path "c:\by3142" -Name "FedUserSynchronizer" -ItemType "directory"
} else {
    #ALL FINE, SKIPPING
}
$fedusersyncpath = "C:\by3142\FedUserSynchronizer"
$rightnow = $(Get-Date -Format "dd-MM-yyyy_HHmmss")
$prettydate = Get-Date -Format "dddd, dd MMMM, yyyy"
$prettytime = Get-Date -Format "HH:mm:ss"
$logpath = "$($fedusersyncpath)\SyncLog_$($rightnow).txt"
Start-Transcript -path $logpath -append

#ENVRINONMENT VARIABLES
$SearchBase = "OU=NONSAKURADA.LAN,OU=Users,OU=Armenia,OU=Sakurada Club,DC=sakurada,DC=lan" #THE OU OF WHICH USERS WILL BE AFFECTED
$UserDescription = "REMOTE DOMAIN USER" #MUST BE ANYWHERE IN USER'S DESCRIPTION FIELD
$RemoteDomain = "studio.lan"
$Users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties Description,Office | Select-Object Name,SamAccountName,Description,Office | Where-Object { $_.Description -like "*$($UserDescription)*" }
$emailnotify = 1 #IF 1, EMAIL NOTIFICATIONS WILL BE SENT, ELSE = THEY WON'T

#CREDS AND AUTH INFO FOR SMTP
$smtplogin = "3142@volnorez.lan"
$smtppw = "YOUR_PASSWORD"
$credentials = New-Object System.Management.Automation.PSCredential(
    $smtplogin,
    (ConvertTo-SecureString $smtppw -AsPlainText -Force)
)
$smtpserver = "smtp.volnorez.lan"
$smtpport = 587
$admins = "zaven@volnorez.lan","nikita@volnorez.lan"

#CORE LOGIC
$Users | ForEach-Object {
    $LocalUser = Get-ADUser $_.SamAccountName -Properties Office,Enabled
    Write-Host "Working on $($LocalUser.Name)..."
    $Error.Clear()
    Try {
        $global:RemoteUser = Get-ADUser $LocalUser.Office -Server $RemoteDomain -Properties Name,SamAccountName,Title,Department,Enabled | Select-Object Name,SamAccountName,Title,Department,Enabled
        #THE OFFICE ATTRIBUTE SHOULD CONTAIN USER'S SAMACCOUNT NAME ON THE REMOTE DOMAIN
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        if (($LocalUser.Enabled -eq $True) -or ($LocalUser.Enabled -eq $null)) {
            Write-Output "$($LocalUser.Name) [$($LocalUser.SamAccountName)] is enabled locally!" -ForegroundColor Green
            $global:NewlyDisabledUserList += "$($LocalUser.Name) | " + "$($LocalUser.SamAccountName)`n"
        }
        Write-Host "$($LocalUser.Name) [$($LocalUser.Office)] was not found in $($RemoteDomain)! Disabling $($LocalUser.SamAccountName) locally!" -ForegroundColor Red
        Disable-ADAccount -Identity $LocalUser.SamAccountName
        $global:NotFoundUserList += "$($LocalUser.Name) | " + "$($LocalUser.SamAccountName) at $($RemoteDomain) `n"
    } catch {
        $Exception = "SCRIPT UNSPECIFIED ERROR:
EXCEPTION NAME: $($_.Exception.GetType().FullName)
EXCEPTION MESSAGE: $($_.Exception.Message)
EXCEPTION ID: $($_.FullyQualifiedErrorId)"
        Write-Host $Exception -ForegroundColor DarkRed
        if ($emailnotify -eq 1) {
            Write-Host "Sending error email to: $($admins)" -ForegroundColor Green
                    Send-MailMessage -To $admins `
                        -From $smtplogin `
                        -Subject "ERROR: FedUserSynchronizer" `
                        -Body "FedUserSynchronizer on $($env:COMPUTERNAME) failed to run at $($prettytime), $($prettydate)!
Check $($logpath) for the error logs! `n`
EXCEPTION DETAILS: $($Exception)" `
                        -SmtpServer $smtpserver `
                        -Port $smtpport `
                        -Credential $credentials `
                        -UseSsl
        } elseif ($emailnotify -ne 1) {
            #SKIPPING
        }
        Write-Host "Exiting!" -ForegroundColor Red
        Exit
    }
    if (!$error) {
        if (($RemoteUser.Enabled -eq $True) -or ($RemoteUser.Enable -eq $null)) { #IF USER IS ENABLED, THE CELL WILL COME BACK EMPTY OR TRUE
        if (($LocalUser.Enabled -eq $False) -and (($RemoteUser.Enabled -eq $True) -or ($RemoteUser.Enable -eq $null))) {
            $NewlyEnabledUserList += "$($LocalUser.Name) | " + "$($LocalUser.SamAccountName)`n"
        }
        Write-Host "$($RemoteUser.Name) [$($RemoteUser.SamAccountName)] is enabled on $($RemoteDomain), enabling $($LocalUser.Name) [$($LocalUser.SamAccountName)] locally." -ForegroundColor DarkGreen
        Enable-ADAccount -Identity $LocalUser.SamAccountName
        Write-Host "Syncrhonizing job title and department names..." -ForegroundColor Cyan
        Set-ADUser -Identity $LocalUser.SamAccountName -Title "$($RemoteUser.Title) | EXTERNAL" -Department "$($RemoteUser.Department) | EXTERNAL"
        Write-Host "Job title (remote):  $($RemoteUser.Title)" -ForegroundColor Gray
        Write-Host "Department (remote): $($RemoteUser.Department)" -ForegroundColor Gray
        Write-Host "Job title set (local): $((Get-ADUser $LocalUser.SamAccountName -Properties Title).Title)" -ForegroundColor DarkGreen
        Write-Host "Department set (local): $((Get-ADUser $LocalUser.SamAccountName -Properties Department).Department)" -ForegroundColor DarkGreen
        } elseif ($RemoteUser.Enabled -eq $False) {
            if (($LocalUser.Enabled -eq $True) -or ($LocalUser.Enabled -eq $null)) {
            Write-Output "$($LocalUser.Name) [$($LocalUser.SamAccountName)] is enabled locally!" -ForegroundColor Green
            $NewlyDisabledUserList += "$($LocalUser.Name) | " + "$($LocalUser.SamAccountName)`n"
            }
            Write-Host "$($RemoteUser.Name) [$($RemoteUser.SamAccountName)] is disabled on $($RemoteDomain), disabling $($LocalUser.Name) [$($LocalUser.SamAccountName)] locally." -ForegroundColor Red
            Disable-ADAccount -Identity $LocalUser.SamAccountName
        }
    } elseif ($error) {
        #SKIPPING
    }
    Write-Output "================"
    Write-Output " "
}

if ((($NewlyDisabledUserList) -or ($NewlyEnabledUserList)) -and ($emailnotify -eq 1)) {
        Write-Host "Sending shutdown email to: $($admins)" -ForegroundColor Green
        Send-MailMessage -To $admins `
            -From $smtplogin `
            -Subject "UPDATE: FedUserSynchronizer" `
            -Body "FedUserSynchronizer successfully ran on $($env:COMPUTERNAME) at $($prettytime), $($prettydate), and updated the user directory!`n`
LIST OF NEWLY SHUT DOWN USERS:
$($NewlyDisabledUserList)
LIST OF NEWLY ENABLED USERS:
$($NewlyEnabledUserList)
For more in-depth logs, check $($logpath)."`
            -SmtpServer $smtpserver `
            -Port $smtpport `
            -Credential $credentials `
            -UseSsl
}

Write-Host @"
USERS WITH ERROR LIST:
$NotFoundUserList 
================
"@
Write-Host @"
NEWLY DISABLED USERS LIST:
$NewlyDisabledUserList 
================
"@

Write-Host @"
NEWLY ENABLED USERS LIST:
$NewlyEnabledUserList 
================
"@

#STOPPING THE TRANSCRIPT
$by3142 = @"
___.           ________  ____   _____ ________  
\_ |__ ___.__. \_____  \/_   | /  |  |\_____  \ 
 | __ <   |  |   _(__  < |   |/   |  |_/  ____/ 
 | \_\ \___  |  /       \|   /    ^   /       \ 
 |___  / ____| /______  /|___\____   |\_______ \
     \/\/             \/          |__|        \/
                 END OF SCRIPT.                
         https://github.com/Volnorez3142        
"@
Write-Host $by3142 -ForegroundColor Magenta
Stop-Transcript
