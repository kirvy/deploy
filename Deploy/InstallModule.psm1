function Install-AXUpdate {
    param (
        [string] $ArtifactsDir,
        [string] $RunBook
    )
    
    # normalize directory path
    $ArtifactsDir = $ArtifactsDir.TrimEnd('\\')
    Push-Location $ArtifactsDir
    # ensure .NET sees correct working directory
    [System.IO.Directory]::SetCurrentDirectory($ArtifactsDir)
    [Environment]::CurrentDirectory = $ArtifactsDir
    
    $installerBase = Join-Path $ArtifactsDir 'Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll'
    if (-not (Test-Path $installerBase)) {
        Write-Error "Cannot find Update installer assemblies in $ArtifactsDir"
        return
    }
    
    Add-Type -Path $installerBase
    Add-Type -Path (Join-Path $ArtifactsDir 'Microsoft.Dynamics.AX.AXInstallationInfo.dll')
    
    $installer = New-Object Microsoft.Dynamics.AX.AXUpdateInstallerBase.AXUpdateInstallerBase
    # generate runbook using new API
    $topologyFile     = Join-Path $ArtifactsDir 'DefaultTopologyData.xml'
    $serviceModelFile = Join-Path $ArtifactsDir 'DefaultServiceModelData.xml'
    
    $runbookFile      = Join-Path $ArtifactsDir "$RunBook.xml"
    
    $installer.Generate(
        $RunBook,
        $topologyFile,
        $serviceModelFile,
        $runbookFile,
        $ArtifactsDir,
        $false  # generateDVTStep
    )
    if (Test-Path "${ArtifactsDir}\$RunBook.xml") {
        $installer.Import("${ArtifactsDir}\$RunBook.xml")
        
        $list = $installer.List()
        if ($list.Contains($RunBook)) {
            $installer.Execute($RunBook, $false, "", $false)    
        }
    }
    Pop-Location
}

Export-ModuleMember -Function Install-AXUpdate