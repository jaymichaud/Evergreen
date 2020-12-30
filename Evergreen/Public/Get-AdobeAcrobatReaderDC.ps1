Function Get-AdobeAcrobatReaderDC {
    <#
        .SYNOPSIS
            Gets the download URLs for Adobe Acrobat Reader DC Continuous track installers.

        .DESCRIPTION
            Gets the download URLs for Adobe Acrobat Reader DC Continuous track installers for the latest version for Windows.

        .NOTES
            Author: Aaron Parker
            Twitter: @stealthpuppy
        
        .LINK
            https://github.com/aaronparker/Evergreen

        .EXAMPLE
            Get-AdobeAcrobatReaderDC

            Description:
            Returns an array with version, installer type, language and download URL for Windows.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding()]
    Param()

    # Get application resource strings from its manifest
    $res = Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1]
    Write-Verbose -Message $res.Name

    #region Installer downloads
    ForEach ($platform in $res.Get.Installer.Platforms) {
        ForEach ($language in $res.Get.Installer.Languages) {
            Write-Verbose -Message "Searching: [$($platform.platform_type)] [$language]"
            $Uri = $res.Get.Installer.Uri -replace "#Platform", $platform.platform_type
            $Uri = $Uri -replace "#Dist", $platform.platform_dist
            $Uri = $Uri -replace "#Language", $language
            $Uri = $Uri -replace "#Arch", $platform.platform_arch
            $Uri = $Uri -replace " ", "%20"
            $iwcParams = @{
                Uri             = $Uri
                Headers         = $res.Get.Installer.Headers
                UserAgent       = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
                UseBasicParsing = $True
                ErrorAction     = $script:resourceStrings.Preferences.ErrorAction
            }
            #$Content = Invoke-WebContent @iwcParams
            $Content = Invoke-WebRequest @iwcParams

            If ($Null -ne $Content) {
                #$ContentFromJson = $Content | ConvertFrom-Json
                $ContentFromJson = $Content.Content | ConvertFrom-Json
                
                # Check properties if multiple values returned
                If ($ContentFromJson.version.Count -eq 1) { $Version = $ContentFromJson.Version } Else { $Version = $ContentFromJson.Version | Select-Object -First 1 }
                If ($ContentFromJson.download_url.Count -eq 1) { $downloadURI = $ContentFromJson.download_url } Else { $downloadURI = $ContentFromJson.download_url | Select-Object -First 1 }
                $PSObject = [PSCustomObject] @{
                    Version  = $Version
                    Type     = "Installer"
                    Language = $language
                    URI      = $downloadURI
                }
                Write-Output -InputObject $PSObject
            }
        }
    }
    #endregion

    #region Update downloads
    $iwcParams = @{
        Uri         = $res.Get.Update.Uri
        ContentType = $res.Get.Update.ContentType
    }
    $Content = Invoke-WebContent @iwcParams

    # Construct update download list
    If ($Null -ne $Content) {
        $versionString = $Content.Replace(".", "")
        $PSObject = [PSCustomObject] @{
            Version  = $Content
            Type     = "Updater"
            Language = "Neutral"
            URI      = $res.Get.Update.Download -replace $res.Get.Update.ReplaceText, $versionString
        }
        Write-Output -InputObject $PSObject
        $PSObject = [PSCustomObject] @{
            Version  = $Content
            Type     = "Updater"
            Language = "Multi"
            URI      = $res.Get.Update.DownloadMsp -replace $res.Get.Update.ReplaceText, $versionString
        }
        Write-Output -InputObject $PSObject
    }
    Else {
        Write-Warning -Message "$($MyInvocation.MyCommand): unable to retreive content from $($res.Get.Update.Uri)."
    }
    #endregion
}
