<#
.SYNOPSIS
Short description

.DESCRIPTION
$queryStr = "SET @command = ''
                    SELECT  @command = @command
                    + 'ALTER DATABASE [' + [name] + ']  SET single_user with rollback immediate;'+CHAR(13)+CHAR(10)
                    + 'DROP DATABASE [' + [name] +'];'+CHAR(13)+CHAR(10)
                    FROM  [master].[sys].[databases] 
                     where [name] not in ( 'master', 'model', 'msdb', 'tempdb');

                    SELECT @command
                    EXECUTE sp_executesql @command"

.PARAMETER LogPath
Parameter description

.PARAMETER CustomQueryFilter
Parameter description

.PARAMETER DatabaseServer
Parameter description

.PARAMETER DatabaseInstance
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Uninstall-NAVAll {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $LogPath = (Join-Path $env:HOMEDRIVE "NAVWorking"),

        [Parameter(Mandatory = $false)]
        [string]
        $CustomQueryFilter = "`'%NAV%`'",

        [Parameter(Mandatory = $false)]
        [string]
        $DatabaseServer = ".",

        [Parameter(Mandatory = $false)]
        [string]
        $DatabaseInstance = "NAVDEMO"
    )
    begin {
        Import-SqlPsModule
    }
    process {
        if(-Not(Test-Path $LogPath))
        {
            $null = New-Item -ItemType Directory -Path $LogPath -Force
        }
        $LogPath = Join-Path $LogPath "Logs"
        if(-Not(Test-Path $LogPath))
        {
            $null = New-Item -ItemType Directory -Path $LogPath -Force
        }
        $nvaWorkingPath = "C:\NAVWorking"
        if(Test-Path $nvaWorkingPath)
        {
            $LogFile = Join-Path $LogPath "UninstAllNAV.log"
            Write-Log "Starting to uninstall all NAV componets by using setup.exe..."
            Write-Log "Looking for Seup.exe file"
            $dvdpath = Get-ChildItem C:\NAVWorking -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "DVD"}
            if($dvdpath)
            {
                $navSetupExe = Join-Path $dvdpath.FullName "setup.exe"
                if(Test-Path $navSetupExe)
                {
                    Write-Log "Found Seup.exe file under $navSetupExe"
                    [string]$argumentList = "-uninstall -quiet -log `"$logFile`""

                    Write-Log "Running Setup.exe to install NAV.."
                    Invoke-ProcessWithProgress -FilePath $navSetupExe -ArgumentList $argumentList -TimeOutSeconds 6000
                }
            }
            else
            {
                Write-Log "Looking for all NAV Component..."
                $allInstalledComponents = Get-WmiObject win32_product -Filter "Name Like '%NAV%'"
                Write-Log "How many components are found: $allInstalledComponents."
                if($allInstalledComponents -ne $null)
                {
                    foreach($component in $allInstalledComponents)
                    {
                        $componentName = $component.Name
                        $IdentifyingNumber = $component.IdentifyingNumber
                        $LogFile = Join-Path $LogPath "UninstAllNAV.log"
        
                        Write-Log "Uninstalling NAV Component: $componentName : $IdentifyingNumber"
                        $ExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/X $IdentifyingNumber REBOOT=ReallySuppress /qb-! /l*v $LogFile" -Wait -Passthru).ExitCode
                        if($ExitCode -eq 0)
                        {
                            Write-Log "Finsihed Uninstalling NAV Component: $componentName : $IdentifyingNumber"
                        }
                        else
                        {
                            Write-Log "Fail to Uninstalling NAV Component: $componentName : $IdentifyingNumber with exit code: $ExitCode"
                        }
                    } 
                }
            }
        }
       
        # Uninstall NAV Database.
        Write-Log "Looking for all NAV Database ..."
        $queryStr = "select name from sys.databases where name like $CustomQueryFilter"
        $serverInstance = "$DatabaseServer`\$DatabaseInstance"

        try
        {
            $allNAVDatabases = Invoke-SQLcmd `
            -ServerInstance $serverInstance `
            -Database master  `
            -Query $queryStr
        
            if ($allNAVDatabases -ne $null)
            {
                foreach($navDB in $allNAVDatabases)
                {
                    $dbName = $navDB.Name
                    Write-Log "Droping NAV Database $dbName  ..."
                    Remove-SqlConnectionsToDatabase -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName $dbName
                    $dropQueryStr = "Drop DATABASE `"$dbName`""
                    Invoke-SQLcmd $dropQueryStr -ServerInstance $serverInstance
                }
            }
        }
        catch
        {
            Write-Exception $_.Exception
        }
        
    }
}

Export-ModuleMember -Function Uninstall-NAVAll

# SIG # Begin signature block
# MIIDzQYJKoZIhvcNAQcCoIIDvjCCA7oCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUiaHy6SLaGrjvMz0iUlh+4oJd
# fgugggH1MIIB8TCCAV6gAwIBAgIQerav1OJGjJREr2hDMeEqHzAJBgUrDgMCHQUA
# MA4xDDAKBgNVBAMTA05BVjAeFw0xNzExMjgwNDAwMzlaFw0zOTEyMzEyMzU5NTla
# MA4xDDAKBgNVBAMTA05BVjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAp5GZ
# c6U30Wj/1Y5mmZpi4BU7Cy1Pbo7gDOVnxvIHCi1Bfivb7WQB3cpp1b2vYeBgH3y0
# Cl9th4bgTy9fPe/zdin57thq/OwJS3qB8rxKazh+Xa3BpHxvAumX7THqZ8ocvirB
# JGIl3K9fDUyeRkPDKq+CC0eqnKDaS6ANuHdvCg8CAwEAAaNYMFYwEwYDVR0lBAww
# CgYIKwYBBQUHAwMwPwYDVR0BBDgwNoAQEgOra+cR2aH3BOGG7Qzr1qEQMA4xDDAK
# BgNVBAMTA05BVoIQerav1OJGjJREr2hDMeEqHzAJBgUrDgMCHQUAA4GBABelU7ZT
# +OXIZH2HfiD4Ngv7lef7RGEaLtBCiXyxkcmTInxY8s6FImkD0Hywf1jcDcU3LeEt
# QnxDsQvfkUFBRHhzFIUvhCxmTHgKfDvisV07bOIrraHuCUAQ+72yrQ7HSRQ5p9z4
# B98bWycdUXSY7mg5l6VilFT2A2Bs03U0WZ82MYIBQjCCAT4CAQEwIjAOMQwwCgYD
# VQQDEwNOQVYCEHq2r9TiRoyURK9oQzHhKh8wCQYFKw4DAhoFAKB4MBgGCisGAQQB
# gjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFLSH08gY
# BHNhTAIEBwXPKqzTBCalMA0GCSqGSIb3DQEBAQUABIGAo+cWsg5rzexoJSVheePY
# qanESM8R124tn8S707k9n3QdNeIrtWenwqT7Dh08MYPONo626+cAX1t9jtQ2mGrh
# ZmZYzCAtgzQ7ymE9aJoDWVTZgOd2rMFSmDiKh58IMJUz+YhyYalHb5S8j7SH0uMD
# Zt4ZgG0myZOW7+1kzysmiOA=
# SIG # End signature block
