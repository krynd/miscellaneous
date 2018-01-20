<#
Robert Hritz
[e-mail address redacted]
2017-09-09
profile_backup.ps1

Script to automate the backup of standard profile information prior to re-imaging.
Backs up:
    User directories (C:\Users\Username)
    User browser profiles

Excludes:
    Default User, Public, and All Users profiles
    Downloads directory
	Virtual Machines
    Most of Application Data, except for browser profile information
    Temp Data & cached files, including Spotify & Pandora caches
    Lock files (file.lock)   
           
Robocopy handles the bulk of the data transfer. A small loop helps Robocopy iterate through individual profiles to copy browser profile data.
Once complete, the file is compressed for storage.
#>

param(
    [switch] $silent = $false,
    [string] $source= "$env:HomeDrive\Users",
    [string] $destination = "$env:SystemDrive\backup\$env:computername--$(get-date -format yyyyMMddTHHmmssffff)",
    [string] $archivedestination = "\\[UNC_Path]\employee backup",
    [string] $threads = "8",
    [string] $retryCount = "3",
    [string] $waitTimer = "5"
)

echo "Source: $source`nDestination: $destination`nArchiveDestination: $archivedestination`nThreads: $threads`nRetryCount: $retryCount`nWaitTimer: $waitTimer`nSilent: $silent"

$excludeDirs= @(“`"Downloads`"","`"Application Data`"",“`"All Users`"”,“`"Default User`"”,“`"Public`"”,“`"test`"”,“`"Spotify`"”,“`"Pandora`"”,
“`"*cache`"”,“`"*Recovery`"”,“`"temp*`"","`"AppData`"","`"VirtualMachines`"", "`"Virtual Machines`"", "`"OneDrive`"")


$excludeFiles=@(“`"*.lock`"”, "`"*.E01`"", "`"*.vmcx`"", "`"*.vmrs`"", "`"*.vhdx`"", "`"*.iso`"")


$logFile = ”$env:TEMP\$env:computername-robocopy-$(get-date -format yyyyMMddTHHmmssffff).log"
$profile_backup_log = "$env:TEMP\$env:computername-profile_backup-$(get-date -format yyyyMMddTHHmmssffff).log"

if ($silent -eq $false)
{
    if (test-path $source)
    {
        while (((read-host -Prompt "Read from $source ? y/n") -eq 'n') -or ([string]::IsNullOrEmpty($source)))
        {
            $source = read-host -prompt "Please enter the source directory. Ex: c:\users"
            
            while (-not (test-path $source))
            {
                $source = Read-Host -prompt "Error: Invalid path. Please enter a valid source"
            }
        }
    }
    else
    {
        while (((-not (test-path $source)) -or ([string]::IsNullOrEmpty($source))))
        {
            $source = Read-Host -prompt "Error: Invalid path. Please enter a valid source"
        }
    }
}
else
{
    if (-not(test-path $source))
    {
        echo "$(get-date -format yyyyMMddTHHmmssffff) Error: Invalid source path: $source`nAs we're running silently, this program will exit" | Tee-Object -Append $profile_backup_log
        sleep 5 # give the user time to read the error message
        exit
    }
}

if ($silent -eq $false)
{
    if (test-path $destination)
    {
        
        while (((read-host -prompt "Write cache to $destination ? y/n?") -eq 'n') -or ([string]::IsNullOrEmpty($destination)))
        {
            $destination = Read-Host -Prompt "Please enter the temporary destination path (ex: c:\backup). This path will be used to store the data locally before compression"
            while (-not (test-path $destination))
            {
                $destination = Read-Host -prompt "Error: Invalid path. Please enter a valid destination"
            }

        }
    }
    else
    {
        new-item $destination -Type Directory -ErrorAction silentlycontinue
        while ((read-host -promp "Write to $destination ? y/n?") -eq 'n')
        {
            $destination = Read-Host -prompt "Error: Invalid path. Please enter a valid destination"
            while ((-not (test-path $destination)) -or ([string]::IsNullOrEmpty($destination)))
            {
                $destination = Read-Host -prompt "Error: Invalid path. Please enter a valid destination"
                new-item $destination -Type Directory -ErrorAction silentlycontinue
            }
        }
    }

    echo "Writing to $destination" | Tee-Object -Append $profile_backup_log
}
else
{
    if (-not (test-path $destination))
    {
        new-item $destination -Type Directory -ErrorAction SilentlyContinue
        if (-not (test-path ($destination)))
        {
            echo "$(get-date -format yyyyMMddTHHmmssffff) Error: Cannot create cache path: $destination`nAs we're running silently, this program will exit" | Tee-Object -Append $profile_backup_log
            sleep 5 # give the user time to read the error message
            exit
        }
    }
    # else: Path exists
}

if ($silent -eq $false)
{
    if (test-path $archivedestination)
    {
        while (((read-host -prompt "Write archive to $archivedestination ? y/n?") -eq 'n') -or ([string]::IsNullOrEmpty($archivedestination)))
        {
            $archivedestination = Read-Host -Prompt "Please enter the destination path (ex: c:\backup or \\UNC_Path\...\backups). This path will be used to store the data after compression"
            while (-not (test-path $archivedestination))
            {
                $archivedestination = Read-Host -prompt "Error: Invalid path. Please enter a valid destination"
            }
        }
    }
    else
    {
        new-item $archivedestination -Type Directory -ErrorAction silentlycontinue
        while (((read-host -prompt "Write archive to $archivedestination ? y/n?") -eq 'n') -or ([string]::IsNullOrEmpty($archivedestination)))
        {
            $archivedestination = Read-Host -Prompt "Please enter the destination path (ex: c:\backup or \\macfs1\...\backups). This path will be used to store the data after compression"
            while (-not (test-path $archivedestination))
            {
                $archivedestination = Read-Host -prompt "Error: Invalid path. Please enter a valid destination"
                new-item $archivedestination -Type Directory -ErrorAction silentlycontinue
            }
        }
    }

    echo "Writing archive to $archivedestination" | Tee-Object -Append $profile_backup_log
}
else
{
    if (-not (test-path $archivedestination))
    {
        echo "$(get-date -format yyyyMMddTHHmmssffff) Error: Invalid destination path: $archivedestination`nAs we're running silently, this program will exit" | Tee-Object -Append $profile_backup_log
        sleep 5 # give the user time to read the error message
        exit
    }
}

# Move log files from temp location to permanent location
if (test-path ($logFile))
{
    echo "$(get-date -format yyyyMMddTHHmmssffff) Moving $logFile" | Tee-Object -Append $logFile
    Move-Item -Path $logFile -Destination ”$destination\$env:computername-$(get-date -format yyyyMMddTHHmmssffff)-robocopy.log"
}
else
{
    # Create log file
    $logFile = ”$destination\$env:computername-$(get-date -format yyyyMMddTHHmmssffff)-robocopy.log"
}
if (test-path ($profile_backup_log))
{
    echo "$(get-date -format yyyyMMddTHHmmssffff) Moving $profile_backup_log" | Tee-Object -Append $profile_backup_log
    Move-Item -Path $profile_backup_log -Destination "$destination\$env:computername-$(get-date -format yyyyMMddTHHmmssffff)-profile_backup.log"
}
else
{
    # Create log file
    $profile_backup_log = "$destination\$env:computername-$(get-date -format yyyyMMddTHHmmssffff)-profile_backup.log"
}

if ($silent -eq $false)
{
#    while(($threads -lt 1) -or ($threads -gt 128) -or ([string]::IsNullOrEmpty($threads)))
#    {
#        $threads = read-host -prompt "Please enter the number of threads you would like to process (e.g. number of simultaneous files to copy). (Default: 8; Valid Range: 1-128)"
#    }
#    while(($retryCount -lt 1) -or ($retryCount -gt 100) -or ([string]::IsNullOrEmpty($retryCount)))
#    {
#        $retryCount = read-host -prompt "Please enter the number of times you would like to retry copying a file. (Suggested value: 3; Valid Range: 1-100)"
#    }
    while(($waitTimer -lt 1) -or ($waitTimer -gt 60) -or ([string]::IsNullOrEmpty($waitTimer)))
    {
        $waitTimer = read-host -prompt "Please enter the number of seconds you would like to wait between retry attempts. (Suggested value: 5; Valid Range: 1-60)"
    }
    echo "Threads: $threads`nRetry: $retryCount`nWait: $waitTimer"
}
else
{
    $threads = 8
    $retryCount = 3
    $waitTimer = 5
}

# Create general log file & log computername
echo "$(get-date -format yyyyMMddTHHmmssffff) Backing up data on: $env:COMPUTERNAME.`
As a reminder, due to API limitations, files greater than 2GB will need manually copied and excluded (moved) prior to running this script." | tee-object -append $profile_backup_log

if ($silent -eq $true)
{
    echo "This script is set to run silently.`nData will be read from: $source`nData will be cached to: $destination`nData will be archived to: $archivedestination" | Tee-Object -Append $profile_backup_log
}
else
{
    if ((read-host -Prompt "Continue: y/n?").ToLower().StartsWith('n'))
    {
        exit
    }
}
# else with remainder of script

echo "$(get-date -format yyyyMMddTHHmmssffff) Backing up user profile data. This will take a while..." | tee-object -append $profile_backup_log
# Copy most of user profile data. Exclude temp files, cache, and other unneeded files
start-process robocopy -ArgumentList @("$source", "$destination", "/copy:dat /e /xd $($($excludeDirs | group | ?{$_.count} | select -ExpandProperty Name) -join ' ') /xf $(($excludeFiles | group | ?{$_.count} | select -ExpandProperty Name) -join ' ') /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -Verb RunAs -Wait
sleep 7
echo "$(get-date -format yyyyMMddTHHmmssffff) Backing up each user's browser profile data" | tee-object -append $profile_backup_log
# Copy user-specific browser information
$userDirs = $(get-childitem $source | Select-object -ExpandProperty Name)

ForEach ($directory in $userDirs)
{
    if (
    ($directory -eq "All Users") -or
    ($directory -eq "Default User") -or
    ($directory -eq "Public") -or
    ($directory -eq "administrator") -or
    ($directory -eq "test")
    )
    {
        continue
    }
    else
    {
        $userbase = Join-Path -path $source -childpath $directory

        # Copy Firefox profile 
        start-process robocopy -argumentlist @("$(join-path -path $userbase -childpath `"AppData\Local\Mozilla\Firefox\Profiles`")", "$(join-path -Path $destination -ChildPath `"$directory\AppData\Local\Mozilla\Firefox\Profiles`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas
        start-process robocopy -argumentlist @("$(join-path -path $userbase -childpath `"AppData\Roaming\Mozilla\Firefox\Profiles`")", "$(join-path -Path $destination -ChildPath `"$directory\AppData\Roaming\Mozilla\Firefox\Profiles`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas

        # Copy Chrome profile
        start-process robocopy -argumentlist @("$(join-path -path $userbase -childpath `"AppData\Local\Google\Chrome\User Data\Default`")", "$(join-path -Path $destination -ChildPath `"$directory\AppData\Local\Google\Chrome\User Data\Default`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas
        start-process robocopy -argumentList @("$(join-path -path $userbase -childpath `"AppData\Roaming\Google\Chrome\User Data\Default`")", "$(join-path -Path $destination -ChildPath `"$directory\AppData\Roaming\Google\Chrome\User Data\Default`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas

        # Internet Explorer History
        start-process robocopy -argumentlist @("$(join-path -path $userbase -childpath `"AppData\Local\Microsoft\Windows\History`")", "$(join-path -path $destination -childpath `"$directory\AppData\Local\Microsoft\Windows\History`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas

        # IE RSS Feeds
        start-process robocopy -argumentlist @("$(join-path $userbase -childpath `"AppData\Local\Microsoft\Feeds`")", "$(join-path -path $destination -childPath `"$directory\AppData\Local\Microsoft\Feeds`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas
    } # End: If
        
} # End: Foreach($directory in $userDirs)

sleep 5

# Active X Controls (Internet Explorer Add-ons)
start-process robocopy -argumentlist @("$env:SystemDrive\Windows\Downloaded Program Files", "$(join-path -path $destination -ChildPath `"Windows\Downloaded Program Files`")", "/copy:dat /e /mt:$threads /r:$retryCount /w:$waitTimer /Z /log+:$logFile /tee") -verb runas -Wait

echo "$(get-date -format yyyyMMddTHHmmssffff) Data backup complete" | tee-object -append $profile_backup_log

<#
if ($silent -eq $false)
{
    $archiveDestination = read-host "Please enter the destination path for the archive (zip file). e.g.: E:\backup or \\fileserver\backup\computername)"
    while (-not (test-path $archiveDestination))
    {
        $archiveDestination = read-host -prompt "Error: invalid archive destination path. Please try again"
    }
}
else
{
    if (-not(test-path $archivedestination))
    {
        echo "$(get-date -format yyyyMMddTHHmmssffff) Cannot connect to $archivedestination. Please check the path and try again" | Tee-Object -Append $profile_backup_log
    }
}
#>

echo "$(get-date -format yyyyMMddTHHmmssffff) Attempting to compress backup files created by this program. This will take a while.`
Please ensure you have sufficient disk space on the local disk and archive destination" | Tee-Object -Append $profile_backup_log

# Tolstoy would be amazed at the size of this warning message
echo "As mentioned previously, due to API limitations, files greater than 2GB will fail to compress.`
This script is set to stop should this occur.`
These files should have been manually copied to their appropriate destination prior to running this script`
If this has not been done so or another compression-related error occurs, it may be necessary to manually run an alternative`
compression utility such as 7-Zip or PeaZip on the locally-held backup, found at $destination"

if ($silent -eq $false)
{
    if ((read-host -prompt "Continue: y/n?").ToLower().StartsWith('n'))
    {
        exit
    }
}

    # Zip files
    $archiveTemp = "$destination\$env:computername--$(get-date -format yyyyMMddTHHmmssffff).zip"
    Compress-Archive -Path $destination -DestinationPath $archiveTemp -CompressionLevel Optimal -ErrorAction Stop

    if (test-path $archiveTemp)
    {
        echo "$(get-date -format yyyyMMddTHHmmssffff) Files succesfully compressed" | Tee-Object -Append $profile_backup_log
    }
    else
    {
        echo "Failed to compress data. Manual intervention required" | Tee-Object -Append $profile_backup_log
    }

    echo "$(get-date -format yyyyMMddTHHmmssffff) Moving archive and logs to archival destination" | Tee-Object -Append $profile_backup_log
    
    # Move zip files and logs to final destination
    # Rotate log files
    $temp = Split-Path $profile_backup_log -Leaf
    if (test-path("$archivedestination\$profile_backup_log"))
    {    
        $filename = [System.IO.Path]::GetFileNameWithoutExtension($temp)
        move-item -path "$archiveDestination\$temp" -Destination (-join("$archiveDestination\$filename--",$(get-date((get-item -Path "$archiveDestination\$temp").lastwritetime) -format filedatetime),".log"))
    }

    $temp = Split-Path $logFile -Leaf
    if (test-path ("$archivedestination\$logFile"))
    {    
        $filename= [system.io.path]::GetFileNameWithoutExtension($temp)
        move-item -path "$archiveDestination\$temp" -Destination (-join("$archiveDestination\$filename--",$(get-date((get-item -Path "$archiveDestination\$temp").lastwritetime) -format filedatetime),".log"))
    }
    Move-Item -Path $archiveTemp -Destination "$archiveDestination" -ErrorAction stop
    move-item -path "$profile_backup_log" -Destination "$archiveDestination" -ErrorAction stop
    move-item -path "$logFile" -Destination $archiveDestination -ErrorAction stop

    echo "$(get-date -format yyyyMMddTHHmmssffff) Profile backup complete"
    sleep 10
    exit
