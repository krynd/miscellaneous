<#
    .SYNOPSIS
        Check for printer-related errors via the Event Viewer log.

    .DESCRIPTION
        Checks Event Viewer for PrintDialog and PrintService errors within a specified timeframe.
        This script assumes it is executing with the appropriate permissions to access the Event Viewer log and write files to the hard drive.

    .INPUTS
        logPath = %systemDrive%\full\path\to\log\directory\root
                Ex: C:\logs
                Default: NULL. Script will later determine if Desktop or TEMP directory are writable.
        logFile = filename.log
                Ex: printerErrors.log
                Default: printerErrors_$Env:COMPUTERNAME_$env:USERDOMAIN.log    For example: printerErrors_testName_EXAMPLEDOMAIN.log
        resultSet = integer representing maximum results to be fetched from Event Viewer
                Ex: 42
                Default: 100
        startTime = dateTime object representing timestamp to use as start point when searching the logs.
                Ex: MM/DD/YYYY    02/29/2000
                Default: 03/19/18
        endTime == dateTime object representing timestamp to use as end point when searching the logs.
                Ex: MM/DD/YYYY    12/25/2025
                Default: 03/30/2018

    .OUTPUTS
        Log file containing verbose list of errors collected by the script. Output location is specified at end of script, but will be the first writable directory among the user's Desktop or Temp directory.

    .EXAMPLE
        ./get-PrinterErrors.ps1
        Run script with default settings.

    .EXAMPLE
        ./get-PrinterErrors.ps1 

    .ROLE
        Member of a Security Group which can read and write to the Event Viewer "Microsoft-Windows-Powershell" / "Windows PowerShell" log.

    .NOTES
        Author: Robert Hritz    robert [dot] hritz7 [at] gmail [dot] com
        Version: 1.0
        Release Date: 2018-03-29
        Planned features for future release:
            Ability to pipe log results to another script.
            Automatic forwarding of log file to file server or e-mail address.

        TROUBLESHOOTING
            File Permissions:
                            Ensure the script is executable and that it is not marked as an Unsafe File because it was downloaded from the Internet.
                            Verify that the local ExecutionPolicy is set to run unsigned scripts or set to Bypass the check for a signed script. This script is not signed.
                            Ensure the account used to execute this script can read & write to the Event Viewer log and to either its Desktop or TEMP directory.
            Insufficient data returned:
                            Adjust the resultSet size and timeframe specified by startTime and endTime. Currently requires manually adjusting the hardcoded values.
            Incorrect data returned:
                            Contact the author of this script in order to request support.
            Parameters are not being passed to the the script.
                            Ensure parameters are passed correctly: -NAME VALUE
                                Ex: -resultSet 20 -startTime "01/01/1970" 

    REQUIRES -Version 3.0
#>

<#
EventID's:
    0: Success
    1: File Access Error

While these EventID's are not installed by default in the Powershell Event Viewer log file, there is no prohibition on using them.
An "error" may be thrown the first time this script is run on this system, but the script will continue and successfully write these log entries.
It appears this also creates the specified EventIDs in the Powershell Event Viewer log, but doesn't add any descriptive information.

Due to a limitation in PowerShell's API, which prevents piping text from STDOUT to an Event Viewer log, log messages are duplicated.
#>

param(
    # By default, the system will determine the most appropriate logPath to save the log file.
    #+ However, this may be overridden by the user if desired.
    [string] $logPath = "",
    [string] $logFile = "printerErrors_$Env:COMPUTERNAME_$env:USERDOMAIN.log",
    [int] $resultSet = 100,

    # startTime and endTime are both string representations of dateTime objects. If required, a dateTime object can be substituted.
    [string] $startTime = "03/19/2018",
    [string] $endTime = "03/30/2018"
)

Begin
{
    if (([string]::IsNullOrEmpty($logPath)) -or ([string]::IsNullOrWhiteSpace($logPath)))
    {
        # Check if current user's Desktop is writable.
        #+ Desktop selected for quick access to outputted file and because custom directories may conflict
        if (test-path "$ENV:UserProfile\Desktop")
        {
            # Can write to user's Desktop
            Write-Host -ForegroundColor Yellow "Writing output log to user's Desktop"
            Write-EventLog -LogName 'Windows PowerShell' -Source "Powershell" -EntryType Information -EventId 0 -Message "Writing output log to user's Desktop"
            $logPath = "$ENV:UserProfile\Desktop"    
        }
        else
        {
            # User's Desktop is not writable
            #+ Either insufficient permissions or this script is running remotely.

            # Attempt to write to the user's Temp Directory (%TEMP%)
            #+ Typically, this is %UserProfile%\AppData\Local\Temp
            #+ For example: C:\Users\Knuckles\AppData\Local\Temp

            #This should work, as using either PSRemoting or PSExec will require local or domain admin credentials to execute the script.

            if (test-path "$ENV:TEMP")
            {
                # Can write to Temp Directory.
        
                # Write-Host with ForegroundColor Yellow emulates standard information streams.
                #+ This is used instead of write-information because PowerShell 2.0 (default Vista & Win7 installations) only has write-host and write-error
                Write-Host  -ForegroundColor Yellow "Writing output log to user's Temp directory"
                Write-EventLog -LogName 'Windows PowerShell' -Source "Powershell" -EntryType Information -EventId 0 -Message "Writing output log to user's Temp diretory"
                $logPath = $ENV:TEMP
            }
            else
            {
                # Cannot write to Temp directory
                #+ Notify the user and abort.
                Write-Error -RecommendedAction Stop -ErrorId 1 -Message "Unable to write to disk. File permission error when attempting to create log file"
                # Logging this error has to be separate from writing to console. It's an unfortunate limitation of PowerShell
                Write-EventLog -LogName 'Windows PowerShell' -Source "Powershell" -EntryType Error -EventId 1 -Message "Unable to write to disk. File permission error when attempting to create log file"
        
                # Exit the script. This assumes the script will not interact with other scripts.
                #+ This will need to be changed for future use so that the output can be piped to a log interpreter.
                Exit-PSHostProcess    # Exit interactive script
                Exit-PSSession        # Exit remotely-executed script

            }
        }
    }
    else
    {
        # Test user-defined path.
        if (-not(test-path $logPath))
        {
            # Cannot access user-defined path.
            do
            {
                $logPath = Read-Host -Prompt "Please enter a valid path"
            } while (-not(test-path $logPath)) # Repeat until a valid path is entered. It is assumed the user will break out of the script if a valid path cannot be entered.
        }
        else
        {
            # User passed valid path
        }

        write-host -ForegroundColor Yellow "Writing to user-defined directory"
    }
    
    # Convert dates to dateTime strings (short timestamps)
    $startTime = '{0:MM/dd/yyyy}' -f $startTime
    $endTime = '{0:MM/dd/yyyy}' -f $endTime
}

process
{
    [string] $logMessage = ""
    $logMessage = (-join("$Env:COMPUTERNAME.$env:USERDOMAIN - $((get-date -format yyyyMMddTHHmmssffff).tostring()) - ",`
    "Collecting up to $resultSet log entries from the selected logs. This may take a while."))

    write-output $logMessage | Tee-Object -FilePath (-join($logPath,"\",$logFile)) -Append

    # Collect the first N results from the logs specified in logname, filtering entries specified in providerName to limit our results to printer-specific errors.
    #+ Return a descending list (newest --> oldest) list of entries, reported between startTime and endTime.
    #+ Log Level 1 = Critical. Level 2 = Error.
    #+ For future reference: Level 3 = Warning. 4 = Informational. 5 = Verbose.

    get-winevent `
        -FilterHashTable @{logname='Microsoft-Windows-PrintService/Admin','Microsoft-Windows-PrintService/Operational','application','system'; `
        providerName='Microsoft-Windows-PrintDialogs','Microsoft-Windows-PrintService';starttime=$startTime;endtime=$endTime;level=1,2} `
        `
        -maxevents $resultSet | select logname, timecreated, id, level, message | out-file (-join($logPath,"\",$logFile)) -Append

    Write-output `
        (-join("$Env:COMPUTERNAME.$env:USERDOMAIN - $((get-date -format yyyyMMddTHHmmssffff).tostring()) - ", `
        "Log file created at $(-join($logPath,"\",$logFile)) . Please forward this log file to your systems administrator.")) `
        | Tee-Object -FilePath (-join($logPath,"\",$logFile)) -Append

    Write-EventLog -LogName 'Windows PowerShell' -Source "Powershell" -EntryType Information -EventId 0 `
        -Message "Log file created at $(-join($logPath,"\",$logFile)) Please forward this log file to your systems administrator."
}

End
{
    write-host -ForegroundColor Yellow "Please inform your systems administrator of the results of this script"
}