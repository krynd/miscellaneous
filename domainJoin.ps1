If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    sleep 10
    exit
}

$domainFull = "[longDomainName]"
$domainShort = "[shortDomainName]"
$deviceName = ((read-host -Prompt "Please enter the new device name").trim().ToUpper())
$usrName = "[domainAdminName]"

if (!(test-path("$env:SystemDrive\Image\")))
{
    mkdir "$env:SystemDrive\Image\"
}
$errorLog = "$env:SystemDrive\Image\$env:computername.txt"

echo (-join("Log file: ",$errorLog))

# Join to domain
try
{
    Rename-Computer -NewName $deviceName -Force
    sleep 5
    Add-Computer -DomainName $domainFull -credential ($host.ui.PromptForCredential("Need credentials", "Please enter your domain admin password.", $usrName, $domainShort)) -force -options JoinWithNewName,AccountCreate -erroraction stop -ErrorVariable domainJoinFail
}
catch
{
    write-host (-join("Failed to join domain ",$domainFull, " as '", $deviceName,"'") | Tee-Object -filepath $errorLog -Append)
    # Sleep for 10 minutes to make sure the operator reads the message.
    write-host "Pausing for 10 minutes. To exit early, press Ctrl+C"
    sleep 600
    exit
}
try
{
    # Add both as domain admin and local admin, this way aaabu1 can be used as local admin regardless of domain membership.
    #+ Possibly duplicates built-in user list from latest image. Left in as added redundancy.
    Add-LocalGroupMember -Group Administrators -member "$domainShort\$usrName" -ErrorAction Continue -ErrorVariable $domainAdminFail
    Add-LocalGroupMember -Group Administrators -member $usrName -ErrorAction Continue -ErrorVariable $domainAdminFail
}
catch
{
        write-host "Failed to promote $usrName to local administrator, most likely because account has yet to be created" | tee-object -FilePath $errorLog -Append
        # Sleep for 10 minutes to make sure the operator reads the message.
        write-host "Pausing for 10 minutes. To exit early, press Ctrl+C"
        sleep 600
        exit
}
write-host "$env:USERDOMAIN successfully joined domain $domainShort as $deviceName on $(get-date -format yyyyMMddTHHmmssffff)" | Tee-Object -FilePath $errorLog -Append
echo "Rebooting in 15 seconds"
sleep 15
Restart-Computer -Force -ErrorAction Stop
echo "Rebooting failed. Please manually reboot device & verify settings have appropriately changed"
sleep 120
exit
