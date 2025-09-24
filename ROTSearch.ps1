<#
.SYNOPSIS
Tool for searching file shares for ROT (Redundant, Obsolete, and Trivial) files.

.DESCRIPTION
This script is used to perform the following functions:
- Recursively search files for ROT
- Create a report with those files

.PARAMETER Path
The path of the drive to search for files. Default is C:\Users\<Username>\Documents drive.

.PARAMETER Aged
Enter only a numberical value for years aged to qualify as obsolete files. Default is 7.

.NOTES
Date                Ver     Author          Details                         
-------------------------------------------------------------------------------------------     
19  Mar 2024        1.0.0   Andrew Kapaldo  Initial Release
22  Mar 2024        1.0.1   Andrew Kapaldo  Added Error Checking and Speed Improvements
24  Sep 2025        1.1.0   Andrew Kapaldo  Added support for MacOS and Linux
#>

[cmdletbinding()]
param(
	[Parameter(Position=0, HelpMessage="Enter Folder Path (Default is C:\Users\<username>\Documents drive)", Mandatory=$False)]
	[string]$path,
	[Parameter(Position=1, HelpMessage="Years aged for obsolete files (default is 7)",Mandatory=$False)]
	[string]$aged,
    [Parameter(HelpMessage="Use creation date instead of modified",Mandatory=$False)]
	[Switch]$UseCreationDate,
    [Parameter(HelpMessage="Use last accessed date instead of modified",Mandatory=$False)]
	[Switch]$UseAccessDate
)
Process {
# Setting default parameters
$ErrorActionPreference = "SilentlyContinue"
$username = $env:username
$OS = [System.Environment]::OSVersion.Platform

# Setting Obsolete Date. If none chosen, default is 7 years.
If (("" -eq $Aged) -or " " -eq $Aged){
        $Aged = "7"
    }
$ObsoleteDate = (get-date).AddYears(-$aged)

# Setting trivial file extensions
$Trivial = @(".tmp", ".temp", ".url", ".lnk", ".log", ".trace", ".debug", ".cache", ".bak", ".backup", ".old")

# Functions to indicate success, failure, and warnings
function Green {
	Write-Host "[+] " -ForeGroundColor "Green" -NoNewLine
}
function Yellow {
	Write-Host "[-] " -ForeGroundColor "Yellow" -NoNewLine
}
function Red {
	Write-Host "[-] " -ForeGroundColor "Red" -NoNewLine
}



If ("" -eq $path){
    Try {
        If ($OS -eq "Win32NT"){
        $path = "C:\Users\$username\Documents"
        }
        elseif ($OS -eq "Unix") {
            $path = "~\Users\$username\Documents"
        }
        else {
            Yellow
            Write-Host "Unknown Operating System. Try using the -Path switch. (Example: ./ROTSearch.ps1 -Path 'C:\Userdata')"
        }
    }
    Catch {
        Red
        Write-Host "Unknown error. Try using the -Path switch. (Example: ./ROTSearch.ps1 -Path 'C:\Userdata')"
    }
}


#Display banner, title, and version
$Title = "
  _____   ____ _______    _____                     _     
 |  __ \ / __ \__   __|  / ____|                   | |    
 | |__) | |  | | | |    | (___   ___  __ _ _ __ ___| |__  
 |  _  /| |  | | | |     \___ \ / _ \/ _`` | '__/ __| '_ \ 
 | | \ \| |__| | | |     ____) |  __/ (_| | | | (__| | | |
 |_|  \_\\____/  |_|    |_____/ \___|\__,_|_|  \___|_| |_|"                                                          

$Version = "1.1.0"
Write-host "$title`nRedundant, Obsolete, and Trivial Search    Version - $version`n" -ForeGroundColor "Cyan"

# Verify the settings for file path, file age, and file extensions are set correctly
If (($aged -ne "") -and ($path -ne "") -and ($trivial -ne "")){
    Green
    Write-host "Settings configured..."
}
Else {
    Red
    Write-Host "Problem configuring settings. Please try again."
    Write-host "Exiting..."
    Start-Sleep -Seconds 3
    Exit
}
    


# Check the folder for existing ROT reports, if they exist remove them. The process uses the -Append function and existing files will have old and new data in the same file.
Green
write-host "Searching $path for existing ROT reports..." 

If (Test-Path -Path "$path\Redundant.csv") {
    Write-Host "    " -NoNewLine
    Red
    Write-Host "Redundant.csv file found. Removing old file..."
    Remove-Item -Path "$path\Redundant.csv"
}
If (Test-Path -Path "$path\Obsolete.csv") {
    Write-Host "    " -NoNewLine
    Red
    Write-Host "Obsolete.csv file found. Removing old file..."
    Remove-Item -Path "$path\Obsolete.csv"
}
If (Test-Path -Path "$path\Trivial.csv") {
    Write-Host "    " -NoNewLine
    Red
    Write-Host "Trivial.csv file found. Removing old file..."
    Remove-Item -Path "$path\Trivial.csv"
}
Else {
    Write-Host "    " -NoNewLine
    Green
    Write-Host "No existing ROT reports found."
}

# Index the folder path - do this once and save to a variable to speed up the processing of each of ROT
Green
write-host "Indexing $path..."
$allfiles = Get-ChildItem -Path $path -File -Recurse -ErrorVariable errors
foreach ($error1 in $errors){
    if ($Null -ne $error1.Exception){
        Write-Host "    " -NoNewLine
        Red
        Write-Host "Exception: $($error1.Exception)"
    }
    Else {
        Write-Host "    " -NoNewLine
        Red
        Write-Host "An error occured during processing."
    }
}
If (($allfiles).Count -eq 0) {
        Write-Host "    " -NoNewLine
        Red
        Write-Host "No files found. Exiting..."
        Start-Sleep -Seconds 3
        Exit
}


#Redundant files xxport
Green
write-host "Searching for redundant files..." 

#Hash the files using SHA256 and compare hashes for duplicates. Run in parallel with up to 5 concurrent sessions for speed.
$files = $allfiles | Group-Object -Property Length | Where-Object { $_.Count -gt 1 } | ForEach-Object -Parallel -ThrottleLimit 5 { $_.Group | Select-Object FullName, Length, @{Name = 'Hash'; Expression = {($_ | Get-FileHash -Algorithm SHA256).Hash}}} -
$R = $files | Group-Object Hash | Where-Object { $_.Count -gt 1 } 

#If there are duplicates, then create a CSV file of them in the folder
If (($R).count -gt 0){
$R | ForEach-Object {$_.Group | select-object FullName, Hash} | Export-CSV "$path\Redundant.csv" -Append -NoTypeInformation
}

If (Test-Path -Path "$path\Redundant.csv") {
    Write-Host "    " -NoNewLine
    Green
    Write-Host "$(($R).count) redundant files found. Details have been placed at $path\Redundant.csv"
}
Else {
    Write-Host "    " -NoNewLine
    Red
    Write-Host "No redundant files found."
}




#Obsolete files export
Green
write-host "Searching for files older than: $ObsoleteDate..."

If ($Using:UseAccessDate){
    #If the UseAccessDate switch is set, check the last access time compared to the ObsoleteDate value (7 years default) for each file
    $o = $allfiles | Where-Object LastAccessTime -lt $ObsoleteDate 

    #If there are files older than the ObsoleteDate, then create a CSV file of them in the folder
    If (($o).count -gt 0){
        $o | select-object FullName, @{Name = 'LastAccessed'; Expression = {$_.LastAccessTime}} | Export-CSV "$path\Obsolete.csv" -Append -NoTypeInformation
    }
}

ElseIf ($Using:UseCreationDate){
    #If the UseCreationDate switch is set, check the created time compared to the ObsoleteDate value (7 years default) for each file
    $o = $allfiles | Where-Object CreationTime -lt $ObsoleteDate 

    #If there are files older than the ObsoleteDate, then create a CSV file of them in the folder
    If (($o).count -gt 0){
        $o | select-object FullName, @{Name = 'Created'; Expression = {$_.CreationTime}} | Export-CSV "$path\Obsolete.csv" -Append -NoTypeInformation
    }
}

Else {
    #Check the last write time compared to the ObsoleteDate value (7 years default) for each file
    $o = $allfiles | Where-Object LastWriteTime -lt $ObsoleteDate 

    #If there are files older than the ObsoleteDate, then create a CSV file of them in the folder
    If (($o).count -gt 0){
        $o | select-object FullName, @{Name = 'LastModified'; Expression = {$_.LastWriteTime}} | Export-CSV "$path\Obsolete.csv" -Append -NoTypeInformation
    }
}

If (Test-Path -Path "$path\Obsolete.csv") {
    Write-Host "    " -NoNewLine
    Green
    Write-Host "$(($O).count) obsolete files found. Details have been placed at $path\Obsolete.csv"
}
Else {
    Write-Host "    " -NoNewLine
    Red
    Write-Host "No files older than $ObsoleteDate found."
}

#Trivial files export
Green
write-host "Searching for trivial file extensions: " -NoNewLine
[system.String]::Join(", ",$Trivial) 

#Check the file extension of each file to see if they match values in the trivial list
$t = $allfiles | Where-Object {$Trivial -eq $_.extension} 

#If there are files with matching extensions, then create a CSV file of them in the folder
If (($t).count -gt 0){
    $t | select-object FullName | Export-CSV "$path\Trivial.csv" -Append -NoTypeInformation
}

If (Test-Path -Path "$path\Trivial.csv") {
    Write-Host "    " -NoNewLine
    Green
    Write-Host "$(($T).count) files with trivial file extensions found. Details have been placed at $path\Trivial.csv"
}
Else {
    Write-Host "    " -NoNewLine
    Red
    Write-Host "No files with these file extensions found: $Trivial"
}

}
