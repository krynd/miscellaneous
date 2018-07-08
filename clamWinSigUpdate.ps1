###########################################################################################################################################
# clamWinSigUpdate.ps1
#
# Description: Downloads alternative ClamAV signatures provided by SaneSecurity and other third-party vendors.
# + Created because ClamWin does not provide a Freshclam.conf (or equivalent) file which is needed to natively add additional repositories.
# + The primary use case for this script is to update the definitions used by ClamWin Portable
# + For now, users of the standard installation of ClamWin would be expected to modify the download directory to suit their needs.
# ++ If desired, contact me for an updated version which would be more user-friendly (likely a C# Windows Forms program).
#
# References:
# + https://forum.iredmail.org/topic12749-iredmail-support-tutorial-increasing-clamav-effectiveness.html
# + https://sanesecurity.com/usage/signatures/
#
# Disclaimer: This script is provided without warranty.
# + The signatures downloaded by this script are the property of their owners / maintainers. No warranty is provided.
#
# Author: Robert Hritz
# + robert[dot]hritz7[at]gmail[dot]com
#
# Date: 20180707
# Revision: 1.0.0
# Changes: Initial Version
###########################################################################################################################################

<#
From https://forum.iredmail.org/topic12749-iredmail-support-tutorial-increasing-clamav-effectiveness.html
Accessed: 20180707

# Sanesecurity + Foxhole
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/junk.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/jurlbl.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/phish.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/rogue.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/sanesecurity.ftm
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/sigwhitelist.ign2
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/scam.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/spamimg.hdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/spamattach.hdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/blurl.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_generic.cdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_filename.cdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_js.cdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_js.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_all.cdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_all.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/foxhole_mail.cdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/malwarehash.hsb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/hackingteam.hsb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/badmacro.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/shelter.ldb

# winnow
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/winnow_malware.hdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/winnow_malware_links.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/winnow_phish_complete_url.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/winnow_extended_malware.hdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/winnow.attachments.hdb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/winnow_bad_cw.hdb

# Malware.expert
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/malware.expert.hdb

# bofhland
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/bofhland_cracked_URL.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/bofhland_malware_URL.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/bofhland_phishing_URL.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/bofhland_malware_attach.hdb

# Porcupine
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/porcupine.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/phishtank.ndb
DatabaseCustomURL http://ftp.swin.edu.au/sanesecurity/porcupine.hsb
#>

# Set download location
# + Users of a permanently-installed edition of ClamWin would need to modify this path to suit their needs
# + Most often, it will be "c:\ProgramData\.clamwin\db", but this has been known to change from time-to-time.
$dbPath = "ClamWinPortable\Data\db"
$downloadPath = $env:TEMP + "\" + $dbPath + "\"
# This script uses the Temp directory so that the user can erase cached virus db files by running Disk Cleanup.
# + Exception: Apparently Windows 8.1 doesn't erase the entire Temp directory.
# ++ As the process used by this script overwrites files with the same name by default, this shouldn't pose a problem.

if (-not(test-path($downloadPath)))
{
    # If temp directory does not exist, manually create it.
    new-item -ItemType Directory -Path $downloadPath
}
else
{
    # Do nothing, path already created
}

# The following are removed because Windows cannot handle filenames which contain periods / dots
# "http://ftp.swin.edu.au/sanesecurity/winnow.attachments.hdb"
# "http://ftp.swin.edu.au/sanesecurity/malware.expert.hdb"

# The following are removed because they are no longer valid file paths.
# "http://ftp.swin.edu.au/sanesecurity/rogue.ndb"

$customURLs = @(
"http://ftp.swin.edu.au/sanesecurity/junk.ndb",
"http://ftp.swin.edu.au/sanesecurity/jurlbl.ndb",
"http://ftp.swin.edu.au/sanesecurity/phish.ndb",
"http://ftp.swin.edu.au/sanesecurity/sanesecurity.ftm",
"http://ftp.swin.edu.au/sanesecurity/sigwhitelist.ign2",
"http://ftp.swin.edu.au/sanesecurity/scam.ndb",
"http://ftp.swin.edu.au/sanesecurity/spamimg.hdb",
"http://ftp.swin.edu.au/sanesecurity/spamattach.hdb",
"http://ftp.swin.edu.au/sanesecurity/blurl.ndb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_generic.cdb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_filename.cdb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_js.cdb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_js.ndb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_all.cdb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_all.ndb",
"http://ftp.swin.edu.au/sanesecurity/foxhole_mail.cdb",
"http://ftp.swin.edu.au/sanesecurity/malwarehash.hsb",
"http://ftp.swin.edu.au/sanesecurity/hackingteam.hsb",
"http://ftp.swin.edu.au/sanesecurity/badmacro.ndb",
"http://ftp.swin.edu.au/sanesecurity/shelter.ldb",
"http://ftp.swin.edu.au/sanesecurity/winnow_malware.hdb",
"http://ftp.swin.edu.au/sanesecurity/winnow_malware_links.ndb",
"http://ftp.swin.edu.au/sanesecurity/winnow_phish_complete_url.ndb",
"http://ftp.swin.edu.au/sanesecurity/winnow_extended_malware.hdb",
"http://ftp.swin.edu.au/sanesecurity/winnow_bad_cw.hdb",
"http://ftp.swin.edu.au/sanesecurity/bofhland_cracked_URL.ndb",
"http://ftp.swin.edu.au/sanesecurity/bofhland_malware_URL.ndb",
"http://ftp.swin.edu.au/sanesecurity/bofhland_phishing_URL.ndb",
"http://ftp.swin.edu.au/sanesecurity/bofhland_malware_attach.hdb",
"http://ftp.swin.edu.au/sanesecurity/porcupine.ndb",
"http://ftp.swin.edu.au/sanesecurity/phishtank.ndb",
"http://ftp.swin.edu.au/sanesecurity/porcupine.hsb"
)

write-host "Dowloading signature updates. This may take a while..."

foreach ($url in $customURLs)
{
    $filename = $url.Split('/') | Select-Object -Last 1
    Invoke-WebRequest -Uri $url -outfile $($downloadPath + $filename)
}

write-host $("Signature update complete. Please manually copy the files in:" + "`n" + $downloadPath + "`n" + "to the appropriate location on your drive.")
# Again, because the use case for this script is for ClamWin Portable, which is USB based and the drive may be mounted on any drive letter,
# + the user must manually copy the database to the appropriate path.