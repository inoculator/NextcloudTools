function restore-ncfile {
<#
.DESCRIPTION
    restores a given file or folder from trashbin
.PARAMETER ncUser
    Mandatory: the nextcloud user that owns the files to restore
.PARAMETER DateAfter
    Optional: datetime value for items deleted after that time
    Default: now -2 days
.PARAMETER DateBefore
    Optional: datetime value for items deleted after that time
    Default: now
.PARAMETER location
    Optional: A regular expression of the relative location in the user root folder from where the item was deleted
    Default: ".*"
.PARAMETER itemName
    Optional: A regular expression of the item name to restore
    Default: ".*"
.PARAMETER force
    Optional: will overwrite existing files and folder.
    Default: false
.PARAMETER whatif
    Optional: if set the run will only return simulated results
#>

#requires -module SimplySQL
[cmdletbinding()]
param (
    [parameter(Mandatory=$true)][string]$ncUser,
    [datetime]$DateAfter = $(get-date).adddays(-2),
    [datetime]$DateBefore = $(get-date),
    [string]$location = ".*",
    [string]$itemName = ".*",
    [switch]$force,
    [switch]$whatif
    )

$dateAfterUX = ([System.DateTimeOffset]$dateAfter).ToUnixTimeSeconds()
$dateBeforeUX = ([System.DateTimeOffset]$dateBefore).ToUnixTimeSeconds()
$ncBaseDir = "/var/www/nextcloud"
$location = [regex]::Escape($location)
$itemName = [regex]::Escape($itemName)

## loading Nextcloud config
$configPath = "$ncBaseDir/config/config.php"
$tmp = "/tmp/readconfig.php"

@"
<?php
include '$configPath';
echo json_encode(`$CONFIG, JSON_PRETTY_PRINT);
?>
"@ | Set-Content $tmp

$NextcloudConfig = php $tmp | ConvertFrom-Json

Remove-Item $tmp

$dbServer = $NextcloudConfig.dbhost -replace ("(^.+)\:.*",'$1')
$dbName = $NextcloudConfig.dbname
$securePass = ConvertTo-SecureString $($NextcloudConfig.dbpassword) -AsPlainText -Force
$dbUser = New-Object System.Management.Automation.PSCredential ($($NextcloudConfig.dbUser), $securePass)
$ncUserRoot = "$($NextcloudConfig.datadirectory)/$ncUser/files"
$TrashBinRoot = "$ncUserRoot/../files_trashbin/files"

write-verbose "##############################`n##"
write-verbose "`$ncUser=$ncUser"
write-verbose "`$DateAfter=$DateAfter"
write-verbose "`$DateBefore=$DateBefore"
write-verbose "`$force=$force"
write-verbose "`$dbserver=$dbserver"
write-verbose "`$dbName = $dbName"
write-verbose "`$dateAfterUX = $dateAfterUX"
write-verbose "`$dateBeforeUX = $dateBeforeUX"
write-verbose "`$ncBaseDir = $ncBaseDir"
write-verbose "`$ncUserRoot = $ncUserRoot"
write-verbose "`$TrashBinRoot = $TrashBinRoot"
write-verbose "`$location = $location"
write-verbose "`$itemName = $itemName"
write-verbose "##`n##############################`n"

if (-not $(test-path $ncUserRoot)) {
    throw("UserRoot not found at $ncUserRoot")
}

if (-not $(test-path $TrashBinRoot)) {
    throw("trashbin not found at $TrashBinRoot")
}

if ($NextcloudConfig.dbtype -ne "mysql") {
    throw("We only support mysql as DBType")
}
###################################
##
## Integrated Functions
##
###################################

function Test-RegexValid {
    param([string]$pattern)

    try {
        [void]([regex]::new($pattern))
        return $true
    }
    catch {
        return $false
    }
}

####################################
##
## main
##
#####################################

if ( -not $(Test-RegexValid $location)) {
    throw ("location not valid")
}
if ( -not $(Test-RegexValid $itemName)) {
    throw ("itemName not valid")
}

try {
    open-mysqlconnection -server $dbServer -Database $dbName -Credential $dbUser -ErrorAction Stop
} catch {
    throw($_)
}

$dbQuery = @"
select * 
from oc_files_trash 
where user = '$ncUser' 
and timestamp >= '$DateAfterUX' 
and timestamp <= '$DateBeforeUX' 
and location rlike '$location'
and id rlike '$itemName'
order by timestamp desc;
"@

write-verbose "`$dbQuery=$dbQuery"

try {
    $dbResult = Invoke-SqlQuery -Query $dbQuery
} catch {
    throw($_)
}

if ($dbResult.count -lt 1) {
    return "No Records found"
}

###########################################
##
##  restore
##
############################################

foreach ($item in $dbResult) {

    ## each item needs to be evaluated first
    $estimatedItemName = $item.id + ".d" + $item.timestamp
    try {
        $LocatedItem = get-item $TrashBinRoot/$estimatedItemName -ErrorAction stop
    } catch {
        Write-Warning "$estimatedItemName not found. Skipping!"
        continue
    }
    ## we found a corresponding item.

    ## extract the original location
    $ItemDestinationFolder = $ncUserRoot + "/" + $item.location

    ## Define the item destination
    $ItemDestination = $ItemDestinationFolder + "/" + $item.id


    ## now check, if that file/folder already exists
    if (Test-Path $ItemDestination) {
        switch ($force) {
            $true  { Write-Warning "$ItemDestination exists. Overwriting by forced flag!" }
            $false { Write-Warning "$ItemDestination exists. Skipping" }
        }

        if (-not $force) { continue }
    }


    ## create the destination if not exists
    new-item -Path $ItemDestinationFolder -ItemType Directory -Force -ErrorAction SilentlyContinue -WhatIf:$whatif

    ##now we move the file/folder
    try {
        move-item $LocatedItem $ItemDestination -Force -ErrorAction stop -WhatIf:$whatif
        write-host "$ItemDestination restored!"
    } catch {
        throw($_)
    }

    if (-not $whatif) {
        ## the item has been moved, now we remove the DBrecord
        $dbQuery = "delete from oc_files_trash where auto_id = '$($item.auto_id)'"
        write-host $dbQuery
        Invoke-SqlQuery -Query $dbQuery -ErrorAction stop |out-null

        ## now we need to reset the permissions
        write-host "resetting permissions on restored object"
        chown -R www-data:www-data $ncUserRoot
        
        ## and we do a file scan -but only on the new item
        write-host "running occ file scan on restored object"
        sudo -u www-data php /var/www/nextcloud/occ files:scan --path="$ncUser/files/$($item.location)"
    } else {
        write-warning "WHATIF set. Skipping orchestrator."
    }

}


#return $dbresult


}