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
$testpwnotifierdir = Test-Path C:\by3142\FedUserSynchronizer
if (-not $test3142dir) {
    Write-Host "No C:\by3142 directory found!" -ForegroundColor Red
    Write-Host "Creating C:\by3142 directory..." -ForegroundColor DarkGreen
    New-Item -Path "c:\" -Name "by3142" -ItemType "directory"
    Write-Host "Creating C:\by3142\FedUserSynchronizer directory..." -ForegroundColor DarkGreen
    New-Item -Path "c:\by3142" -Name "FedUserSynchronizer" -ItemType "directory"
} elseif (-not $testpwnotifierdir) {
    Write-Host "No C:\by3142\FedUserSynchronizer directory found!" -ForegroundColor Red
    Write-Host "Creating C:\by3142\FedUserSynchronizer directory..." -ForegroundColor DarkGreen
    New-Item -Path "c:\by3142" -Name "FedUserSynchronizer" -ItemType "directory"
} else {
    #ALL FINE, SKIPPING
}
$pwnotifierpath = "C:\by3142\FedUserSynchronizer\"
Start-Transcript -path C:\by3142\FedUserSynchronizer\SyncLog_$(Get-Date -Format "yyyy-MM-dd_HHmmss").txt -append

#ENVRINONMENT VARIABLES
$SearchBase = "OU={NONSAKURADA.LAN},OU=Users,OU=Armenia,OU=Sakurada Club,DC=sakurada,DC=lan" #THE OU OF WHICH USERS WILL BE AFFECTED
$UserDescription = "REMOTE DOMAIN USER" #MUST BE ANYWHERE IN USER'S DESCRIPTION FIELD
$RemoteDomain = "studio.lan"
$Users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties Description,Office | Select-Object Name,SamAccountName,Description,Office

#CORE LOGIC
$Users | ForEach-Object {
    if ($_.Description -like "*$($UserDescription)*") { 
        $LocalUser = Get-ADUser $_.SamAccountName -Properties Office
        Write-Host "Working on $($LocalUser.Name)..."
        $RemoteUser = Get-ADUser $LocalUser.Office -Server $RemoteDomain -Properties Name,SamAccountName,Title,Department,Enabled | Select-Object Name,SamAccountName,Title,Department,Enabled
        #THE OFFICE ATTRIBUTE SHOULD CONTAIN USER'S SAMACCOUNT NAME ON THE REMOTE DOMAIN
        if ($RemoteUser.Enabled -eq $null) { #IF USER IS ENABLED, THE CELL WILL COME BACK EMPTY
            Write-Host "$($RemoteUser.Name) [$($RemoteUser.SamAccountName)] is enabled on $($RemoteDomain), enabling $($LocalUser.Name) [$($LocalUser.SamAccountName)] locally." -ForegroundColor DarkGreen
            Enable-ADAccount -Identity $LocalUser.SamAccountName
            Write-Host "Syncrhonizing job title and department names..." -ForegroundColor Cyan
            Set-ADUser -Identity $LocalUser.SamAccountName -Title $RemoteUser.Title -Department $RemoteUser.Department
            Write-Host "Job title:  $((Get-ADUser $LocalUser.SamAccountName -Properties Title).Title)" -ForegroundColor Gray
            Write-Host "Department: $((Get-ADUser $LocalUser.SamAccountName -Properties Department).Department)" -ForegroundColor Gray
        } elseif ($RemoteUser.Enabled -eq $False) {
            Write-Host "$($RemoteUser.Name) [$($RemoteUser.SamAccountName)] is disabled on $($RemoteDomain), disabling $($LocalUser.Name) [$($LocalUser.SamAccountName)] locally." -ForegroundColor Red
            Disable-ADAccount -Identity $LocalUser.SamAccountName
        }
        Write-Output "================"
        Write-Output " "
    }
}

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