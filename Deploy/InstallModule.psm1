function Install-AXUpdate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string] $ArtifactsDir = (Get-Location).Path,

        [ValidatePattern('^[^<>:"/\\|?*]+$')]
        [string] $RunBook = 'axupdate'
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw "AXUpdateInstaller assemblies require Windows PowerShell 5.1. Start 'powershell.exe' instead of PowerShell 7+, then run Install-AXUpdate again."
    }

    if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
        $ArtifactsDir = (Get-Location).Path
    }

    if ([string]::IsNullOrWhiteSpace($RunBook)) {
        $RunBook = 'axupdate'
    }
    
    $resolvedArtifactsDir = (Resolve-Path -LiteralPath $ArtifactsDir).ProviderPath
    $ArtifactsDir = if ($resolvedArtifactsDir -eq [System.IO.Path]::GetPathRoot($resolvedArtifactsDir)) {
        $resolvedArtifactsDir
    }
    else {
        $resolvedArtifactsDir.TrimEnd('\')
    }
    $originalDirectory = [Environment]::CurrentDirectory
    Write-Verbose "Using artifacts directory '$ArtifactsDir'."
    Write-Verbose "Using runbook name '$RunBook'."

    if ($ArtifactsDir.Contains(' ')) {
        throw "AXUpdateInstaller cannot execute from a package path containing spaces. Move the package to a path without spaces, then run Install-AXUpdate again."
    }
    
    Push-Location $ArtifactsDir
    try {
        # ensure .NET sees correct working directory
        [System.IO.Directory]::SetCurrentDirectory($ArtifactsDir)
        [Environment]::CurrentDirectory = $ArtifactsDir
        
        $requiredFiles = @(
            'Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll',
            'Microsoft.Dynamics.AX.AXInstallationInfo.dll',
            'DefaultTopologyData.xml',
            'DefaultServiceModelData.xml',
            'HotfixInstallationInfo.xml'
        )

        foreach ($requiredFile in $requiredFiles) {
            $requiredPath = Join-Path $ArtifactsDir $requiredFile
            if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
                throw "Cannot find required file '$requiredFile' in '$ArtifactsDir'."
            }
        }

        $blockedFiles = Get-ChildItem -LiteralPath $ArtifactsDir -File -Recurse |
            Where-Object {
                $_.Extension -in '.dll', '.exe' -and
                (Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue)
            }

        if ($blockedFiles) {
            $blockedFileList = ($blockedFiles | Select-Object -ExpandProperty FullName) -join ', '
            throw "Windows is blocking one or more installer assemblies: $blockedFileList. Review the package source, then run: Get-ChildItem -LiteralPath '$ArtifactsDir' -File -Recurse | Where-Object { `$_.Extension -in '.dll', '.exe' } | Unblock-File"
        }
        
        $installerBase = Join-Path $ArtifactsDir 'Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll'
        $installationInfo = Join-Path $ArtifactsDir 'Microsoft.Dynamics.AX.AXInstallationInfo.dll'
        # generate runbook using new API
        $topologyFile     = Join-Path $ArtifactsDir 'DefaultTopologyData.xml'
        $serviceModelFile = Join-Path $ArtifactsDir 'DefaultServiceModelData.xml'
        
        $runbookFile      = Join-Path $ArtifactsDir "$RunBook.xml"
        Write-Verbose "Runbook file will be '$runbookFile'."
        
        if ($PSCmdlet.ShouldProcess($ArtifactsDir, "Generate, import, and execute runbook '$RunBook'")) {
            Write-Verbose "Loading AX update installer assemblies."
            Add-Type -Path $installerBase
            Add-Type -Path $installationInfo
            
            $installer = New-Object Microsoft.Dynamics.AX.AXUpdateInstallerBase.AXUpdateInstallerBase

            Write-Verbose "Generating runbook '$RunBook'."
            $installer.Generate(
                $RunBook,
                $topologyFile,
                $serviceModelFile,
                $runbookFile,
                $ArtifactsDir,
                $false  # generateDVTStep
            )
            if (Test-Path -LiteralPath $runbookFile -PathType Leaf) {
                Write-Verbose "Importing runbook '$runbookFile'."
                $installer.Import($runbookFile)
                
                $list = $installer.List()
                if ($list.Contains($RunBook)) {
                    Write-Verbose "Executing runbook '$RunBook'."
                    $installer.Execute($RunBook, $false, $ArtifactsDir, $false)
                }
                else {
                    throw "Runbook '$RunBook' was not found after import."
                }
            }
            else {
                throw "Runbook file '$runbookFile' was not generated."
            }
        }
    }
    finally {
        Pop-Location
        [System.IO.Directory]::SetCurrentDirectory($originalDirectory)
        [Environment]::CurrentDirectory = $originalDirectory
    }
}

Export-ModuleMember -Function Install-AXUpdate
