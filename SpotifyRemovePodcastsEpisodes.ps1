#Requires -Version 3
<#
.SYNOPSIS
  Powershell Spotify Remove Podcasts and Episodes script
.DESCRIPTION
  Locates and edits spotify file %appdata%/spotify/apps/xpui.spa to alter the UI behavior
.INPUTS
  None
.OUTPUTS
  None unless an error occurs
.NOTES
  Version:        1.1
  Author:         Doug Barry
  Creation Date:  20220223
  Purpose/Change: Fix issue #2: https://github.com/DougBarry/powershell-spotify-remove-podcasts/issues/2

  Version:        1.0
  Author:         Doug Barry
  Creation Date:  20220111
  Purpose/Change: Initial script development

  Powershell Spotify Remove Podcasts and Episodes script
  Windows Powershell version of Remy's script. See their blog post: https://remysharp.com/2021/08/17/removing-shows-from-spotify
  Zip manipulation segments from https://stackoverflow.com/questions/25538501/edit-zip-file-content-in-subfolder-with-powershell/49337731

.EXAMPLE
  ./scriptname.ps1
#>

# Name of target .spa file
$SPAFILETargetName = "xpui.spa"

# Name of file inside .spa archive to search and replace within
$XPUIFileTargetName = "xpui.js"

$SearchReplace = @{
  'withQueryParameters(e){return this.queryParameters=e,this}' = 'withQueryParameters(e){return this.queryParameters=(e.types?{...e, types: e.types.split(",").filter(_ => !["episode","show"].includes(_)).join(",")}:e),this}'
}

$ErrorActionPreference = "Stop"

# Load ZipFile (Compression.FileSystem) if necessary
try { $null = [IO.Compression.ZipFile] }
catch { [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') }

# Locate Spotify appdata root and Spotift apps path
$SpotifyAppdataRoot = Join-Path -Path "$([Environment]::GetFolderPath('ApplicationData'))" -ChildPath "Spotify"
$SpotifyAppsPath = Join-Path -Path $SpotifyAppdataRoot -ChildPath "Apps"

$SpotifyXPUIdotSPA = (Get-ChildItem -Path $SpotifyAppsPath -Filter "$($SPAFILETargetName)" | Select-Object -First 1).FullName
$SpotifyXPUIdotSPABackup = "$($SpotifyXPUIdotSPA).bak"

# Backup file
try { Copy-Item -Path $SpotifyXPUIdotSPA -Destination $SpotifyXPUIdotSPABackup -ErrorAction Stop }
catch { throw "Unable to back up file $($SpotifyXPUIdotSPA)" }

# Open zip file with update mode (Update, Read, Create -- are the options)
try { $SpotifyXPUISPAFile = [System.IO.Compression.ZipFile]::Open( $SpotifyXPUIdotSPA, 'Update' ) }
catch { throw "Unable to open archive $($SpotifyXPUIdotSPA)" }

$FindXPUI = $SpotifyXPUISPAFile.Entries | Where-Object { $_.FullName -eq $XPUIFileTargetName }

# Try to file the file inside the zip
if ($null -eq $FindXPUI) { throw "Unable to open archive $($XPUIFileTargetName)" }

# Open the content into a string via a stream reader
try {
    $XPUIStreamReader = [System.IO.StreamReader]$( $SpotifyXPUISPAFile.Entries | Where-Object { $_.FullName -eq $XPUIFileTargetName }).Open()
    $XPUIFileContent = $XPUIStreamReader.ReadToEnd()
    $XPUIStreamReader.Close()
    $XPUIStreamReader.Dispose()

    # Manipulate content in string
    foreach ($Pair in $SearchReplace.GetEnumerator())
    {
      $XPUIFileContent = $XPUIFileContent.Replace($Pair.Name, $Pair.Value)
    }

    # Open stream writer to alter zipped contents
    $XPUIStreamWriter = [System.IO.StreamWriter]$( $SpotifyXPUISPAFile.Entries | Where-Object { $_.FullName -eq $XPUIFileTargetName }).Open()

    # If needed, zero out the file -- in case the new file is shorter than the old one
    $XPUIStreamWriter.BaseStream.SetLength(0)

    # Insert the $text to the file and close
    $XPUIStreamWriter.Write($XPUIFileContent)
    $XPUIStreamWriter.Flush()
    $XPUIStreamWriter.Close()

    $SpotifyXPUISPAFile.Dispose()
}
catch {
    throw "Unable to make changes to file $($SpotifyXPUISPAFile)"
}
