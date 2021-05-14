param (
  [string]$releasePeriod,
  [string]$commonScriptPath,
  [string]$releaseDirectory,
  [string]$repoLanguage,
  [string]$changedPackagesPath
)

function AddChangelogUrls ()
{
    $changedPackages = (Get-Content -Path $changedPackagesPath | ConvertFrom-Json).where({ $_.Language -eq $repoLanguage })

    LogDebug "Changed Packages: $($changedPackages.Count)"
    LogDebug "Repo Language: $repoLanguage"

    foreach ($package in $changedPackages)
    {
        LogDebug "Package Language: $($package.Language)"
        $language = $package.Language
        if ($language -eq "dotnet")
        {
            $language = "net"
            $package.Language = $language
        }
        $packageName = $package.Package
        $packageDirName = $package.Package
        if ($language -eq "js")
        {
            # Remove @azure/
            $packageDirName = ($packageDirName.split("/"))[1]
        }
        LogDebug "language: $language"
        $package | Add-Member -NotePropertyName "PackageDirName" -NotePropertyValue $packageDirName
        $serviceName = $package.RepoPath
        $updatedVersion = $package.UpdatedVersion
        $changelogRawUrl = "https://raw.githubusercontent.com/Azure/azure-sdk-for-" + `
                                "${language}/${packageName}_${updatedVersion}/sdk/${serviceName}/${packageDirName}/CHANGELOG.md"
        $package | Add-Member -NotePropertyName "UpdatedChangelogUrl" -NotePropertyValue $changelogRawUrl
        LogDebug "Changelog $changelogRawUrl Added"
    }
    return $changedPackages
}

function GetReleaseNotesData ($changedPackages)
{
    $entries = @()
    foreach ($package in $changedPackages)
    {
        try
        {
            $changelogContent = Invoke-RestMethod -Method GET -Uri $package.UpdatedChangelogUrl -MaximumRetryCount 2
        }
        catch
        {
            # Skip if the changelog Url is invalid
            LogWarning "Failed to get content from $($package.UpdatedChangelogUrl)"
            continue
        }
        $tempFile = New-TemporaryFile
        Set-Content -Path $tempFile.FullName -Value $changelogContent
        $changeLogEntries = Get-ChangeLogEntries -ChangeLogLocation $tempFile.FullName
        foreach ($changelogEntry in $changeLogEntries.Values)
        {
            if ($changeLogEntry.ReleaseVersion -ne $package.UpdatedVersion)
            {
                LogDebug "Skipping States: $($changeLogEntry.ReleaseVersion) released on $($changeLogEntry.UpdatedVersion)"
                continue
            }

            $githubAnchor = $changeLogEntry.ReleaseTitle.Replace("## ", "").Replace(".", "").Replace("(", "").Replace(")", "").Replace(" ", "-")

            $releaseTag = "${package.Package}_${$package.UpdatedVersion}"
            $ChangelogUrl = "https://github.com/Azure/azure-sdk-for-" + `
                            "$($package.Language)/blob/${releaseTag}/sdk/$($package.RepoPath)/$($package.PackageDirName)/CHANGELOG.md#${githubAnchor}"
            $packageSemVer = [AzureEngSemanticVersion]::ParseVersionString($package.UpdatedVersion)
            $releaseEntryContent = @()
            $changeLogEntry.ReleaseContent | %{
                $releaseEntryContent += $_.Replace("###", "####")
            }

            $entry = [ordered]@{
                Name = $package.Package
                Version = $package.UpdatedVersion
                DisplayName = $package.DisplayName
                ServiceName = $package.ServiceName
                VersionType = $packageSemVer.VersionType
                Hidden = $false
                ChangelogUrl = $ChangelogUrl
                ChangelogContent = ($releaseEntryContent | Out-String).Trim()
            }

            if (!$entry.DisplayName)
            {
                $entry.DisplayName = $entry.Name
            }

            if ($package.GroupId)
            {
                $entry.Add("GroupId", $package.GroupId)
            }

            $entries += $entry
            LogDebug "Entry $entry Added"
        }
    }
    return $entries
}

. (Join-Path $commonScriptPath ChangeLog-Operations.ps1)
. (Join-Path $commonScriptPath SemVer.ps1)

#. $commonScript
#$CsvMetaData = Get-CSVMetadata -MetadataUri "https://raw.githubusercontent.com/azure-sdk/azure-sdk/PackageVersionUpdates/_data/releases/latest/${releaseFileName}-packages.csv"

$releaseFilePath = (Join-Path $ReleaseDirectory $releasePeriod "${repoLanguage}.md")
$pathToRelatedYaml = (Join-Path $ReleaseDirectory ".." _data releases $releasePeriod "${repoLanguage}.yml")
LogDebug "Release File Path [ $releaseFilePath ]"
LogDebug "Related Yaml File Path [ $pathToRelatedYaml ]"

if (!(Test-Path $pathToRelatedYaml))
{
    New-Item -Path $pathToRelatedYaml -Force
    Set-Content -Path $pathToRelatedYaml -Value @("entries:")
}

# Install Powershell Yaml
$ProgressPreference = "SilentlyContinue"
$ToolsFeed = "https://pkgs.dev.azure.com/azure-sdk/public/_packaging/azure-sdk-tools/nuget/v2"
Register-PSRepository -Name azure-sdk-tools-feed -SourceLocation $ToolsFeed -PublishLocation $ToolsFeed -InstallationPolicy Trusted -ErrorAction SilentlyContinue
Install-Module -Repository azure-sdk-tools-feed powershell-yaml

$existingYamlContent = ConvertFrom-Yaml (Get-Content $pathToRelatedYaml -Raw) -Ordered

$changedPackages = AddChangelogUrls
$incomingReleaseEntries = GetReleaseNotesData -changedPackages $changedPackages
$filteredEntries = @()

if($existingYamlContent.entries)
{
    foreach ($entry in $incomingReleaseEntries)
    {
        $presentKey = $existingYamlContent.entries.Where( { ($_.name -eq $entry.name) -and ($_.version -eq $entry.version) } )
        if ($presentKey.Count -gt 0)
        {
            continue
        }
        $filteredEntries += $entry
    }
}
else 
{
    $filteredEntries = $incomingReleaseEntries
}

if ($null -eq $existingYamlContent.entries)
{
    $existingYamlContent.entries = New-Object "System.Collections.Generic.List[System.Collections.Specialized.OrderedDictionary]"
}

foreach ($entry in $filteredEntries)
{
    $existingYamlContent.entries += $entry
    LogDebug "Entry $entry Updated"

}

#Set-Content -Path $pathToRelatedYaml -Value (ConvertTo-Yaml $existingYamlContent)
#
#if (!(Test-Path $releaseFilePath) -and $existingYamlContent.entries.Count -gt 0)
#{
#    &(Join-Path $PSScriptRoot Generate-Release-Structure.ps1) -releaseFileName "${repoLanguage}.md" -ExcludeFileNames @()
#}
