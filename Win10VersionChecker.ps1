<#
Robert Hritz
2017-10-11
[e-mail address redacted]
Windows10_VersionChecker.ps1
Script to poll all PCs on domain and report on which version of Windows 10 they are using. Useful to find EOL installations.
#>
$logfile = (-join($env:homedrive,$env:homepath,"\","Documents","\","$(get-date -format yyyyMMddTHHmmssffff)-Win10_Versions.log"))

$results = 500

$winList=@{
10240 = "RTM";
10586 = "November Update";
14393 = "Anniversary Update";
15063 = "Creators Update"}

$computers = Get-ADComputer -filter { (OperatingSystem -like "Windows 10*") } -SearchScope Subtree -properties * -ResultSetSize $results | select-object "Name","OperatingSystemVersion"

foreach($comp in $computers)
{
    # Flush the file buffer
    [console]::out.flush()

    # Find Windows OS Build number
    $name = $comp.name.tostring()
    $temp = $comp.operatingsystemversion.tostring()
    $temp = $temp.split("(")
    $temp = $temp.split(")")
    $osRevision = $temp[1]
    $osName = $winList.get_item([convert]::ToInt32($osRevision,10))
   # echo "OS Name: $osName"
    echo (-join($name.padright(15,[char]32), "`t", $osRevision, "`t", $osName)) | tee-object $logfile -Append
}

echo $logfile
