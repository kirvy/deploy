#parameters
param(
    [Parameter()]
    [AllowEmptyString()]
    [string] $username,

    [Parameter (Mandatory=$True)]
    [string] $accessToken,

    [Parameter (Mandatory=$True)]
    [string] $buildDefinitionName,

    [Parameter (Mandatory=$True)]
    [string] $vstsProjectUri,

    [Parameter (Mandatory=$True)]
    [string] $runBook
)

Set-PSDebug -Strict

# VSTS Variables
$vstsApiVersion = "2.0"

# Script Variables
$script:outDir = $PSScriptRoot + "\" + $buildDefinitionName 
$script:build = $null

function ParseUrlQuery
{
    param (
        [Parameter(Position=0)]
        [string] $url,

        [Parameter(Position=1)]
        [string] $queryKey
    )
        
    $url = $url -replace "%24", ""
    $idx = $url.LastIndexOf("?")

    if ($idx -gt 0)
    {
        $url = $url.Substring($idx + 1, $url.Length - $idx - 1)
    }

    $httpValueCollection = [System.Web.HttpUtility]::ParseQueryString($url)
    return $httpValueCollection[$queryKey]
}

function SetAuthHeaders
{
    $basicAuth = ("{0}:{1}" -f $username,$accessToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    return @{Authorization=("Basic {0}" -f $basicAuth)}
}

function GetBuildDefinitionId
{
    $buildDefinitionUri = ("{0}/_apis/build/definitions?api-version={1}&name={2}" -f $vstsProjectUri, $vstsApiVersion, $buildDefinitionName)
    try
    {
        Write-Output "GetBuildDefinitionId from $buildDefinitionUri"
        $buildDef = Invoke-RestMethod -Uri $buildDefinitionUri -Headers $headers -method Get -ErrorAction Stop
        return $buildDef.value.id
    }
    catch
    {
        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
        {
            $errMsg = $Error[0].Exception.Message
            Write-Error $errMsg
        }
        exit -1
    }
}

function GetLatestBuild
{
    param (
        [Parameter(Mandatory=$True)]
        [int] $buildDefinitionId 
    )
    $buildUri = ("{0}/_apis/build/builds?api-version={1}&definitions={2}&resultFilter=succeeded" -f $vstsProjectUri, $vstsApiVersion, $buildDefinitionId);

    try 
    {
        Write-Output "GetLatestBuild from $buildUri"
        $builds = Invoke-RestMethod -Uri $buildUri -Headers $headers -Method Get -ErrorAction Stop | ConvertTo-Json | ConvertFrom-Json
        return $builds.value[0]
    }
    catch
    {
        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
        {
            $errMsg = $Error[0].Exception.Message
            Write-Error $errMsg
        }
        exit -1
    }
   
}

function DownloadBuildArtifacts
{
    if ($vstsProjectUri.EndsWith("/")) {
        $vstsProjectUri = $vstsProjectUri.Substring(0, $vstsProjectUri.Length -1)
    }

    $headers = SetAuthHeaders
    $build = GetLatestBuild ( GetBuildDefinitionId )

    Write-Output "Lastest successful build found:"
    Write-Output "  Id: $($build.Id)"
    Write-Output "  Number: $($build.buildNumber)"
    Write-Output "  Finished: $($build.finishTime)"

    $artifactsUri = ("{0}/_apis/build/builds/{1}/Artifacts?api-version={2}" -f $vstsProjectUri, $build.Id, $vstsApiVersion);

    $script:outDir = $outDir + "\" + $build.Id + "-" + $(get-date -f yyMMddHHmmss) 

    try 
    {
        if (! (Test-Path $outDir))
        {
            # Get-ChildItem -Path $outDir | Remove-Item -Verbose -Recurse   
            New-Item -ItemType Directory -Path $outDir
        }

        if (! (Test-Path "$outDir\Packages"))
        {
            New-Item -ItemType Directory -Path "$outDir\Packages"
        }

        Write-Output "Get artifacts from $artifactsUri"
        $artifacts = Invoke-RestMethod -Uri $artifactsUri -Headers $headers -Method Get  -ErrorAction Stop | ConvertTo-Json -Depth 3 | ConvertFrom-Json
        
        foreach ($artifact in $artifacts.value)
        {
            $DownloadUri  = $artifact.resource.downloadUrl
            $artifactName = $artifact.name

            if ($artifact.resource.type -eq "Container")
            {
                Write-Output "Download $artifactName from $DownloadUri"

                $fileFormat = ParseUrlQuery $downloadUri "format"
                $outFile    = ParseUrlQuery $downloadUri "fileName"

                if ($outFile -eq $null)
                {
                    $outFile = "$artifactName.$fileFormat"
                }

                $outFile = $outDir + "\" + $outFile
                Invoke-RestMethod -Uri $artifact.resource.downloadUrl -Headers $headers -Method Get -OutFile $outFile -ErrorAction Stop
            }
        }

        $filePackages = $outDir + "\Packages.zip"

        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
        if (Test-Path $filePackages)
        {
            Write-Output "Unpacking packages $filePackages"
            [System.IO.Compression.ZipFile]::ExtractToDirectory($filePackages, $outDir)
        }

        $packages = Get-ChildItem -Path "$outDir\Packages" -Filter AXDeployableRuntime*.zip
                
        if ($packages.Count -eq 1)
        {
            Write-Output "Unpacking package $packages[0].FullName"
            [System.IO.Compression.ZipFile]::ExtractToDirectory($packages[0].FullName, "$outDir\Packages")
        }

    }
    catch
    {
        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
        {
            $errMsg = $Error[0].Exception.Message
            Write-Error $errMsg
        }
        exit -1
    }
}
 
function InstallUpdate
{
    Write-Output "Loading Update installer assemblies"

    if (! (Test-Path -Path "$outDir\Packages\Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll"))
    {
        Write-Error "Cannot find Update installer assemblies"
        return
    }

    Add-Type -Path "$outDir\Packages\Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll"
    Add-Type -Path "$outDir\Packages\Microsoft.Dynamics.AX.AXInstallationInfo.dll"

    Write-Output "Generating runbook"

    $runbookGenerator = New-Object -TypeName Microsoft.Dynamics.AX.AXUpdateInstallerBase.RunbookGenerator

    [Microsoft.Dynamics.AX.AXUpdateInstallerBase.AXUpdateInstallerBase]::generate(
        $runbook,
        "$outDir\Packages\DefaultTopologyData.xml",
        "$outDir\Packages\DefaultServiceModelData.xml",
        "$outDir\Packages\$runbook.xml",
        "$outDir\Packages",
        $runbookGenerator,
        $False
    );

    if (Test-Path "$outDir\Packages\$runbook.xml")
    {
        Write-Output "Generated runbook $runbook at $outDir\Packages\$runbook.xml"

        [Microsoft.Dynamics.AX.AXUpdateInstallerBase.AXUpdateInstallerBase]::import(
            "$outDir\Packages\$runbook.xml"
        );

        $runbookList = [Microsoft.Dynamics.AX.AXUpdateInstallerBase.AXUpdateInstallerBase]::list();
                
        if ($runbookList.Contains($runbook))
        {
            Write-Output "Imported runbook $runbook"
                        
            Write-Output "Executing runbook $runbook"
            $runbookExecutor = New-Object -TypeName Microsoft.Dynamics.AX.AXUpdateInstallerBase.RunbookExecutor

            $packagePath = "$outDir\Packages"

            $command = "$outDir\Packages\AXUpdateInstaller.exe"
            $arguments = "execute -runbookid=$runbook"

            Write-Output $command $arguments

            $process = Start-Process $command -ArgumentList $arguments -PassThru -Wait -NoNewWindow

            # [Microsoft.Dynamics.AX.AXUpdateInstallerBase.AXUpdateInstallerBase]::execute(
            #     $runbook,
            #     $False,
            #     $packagePath,
            #     $runbookExecutor,
            #     $True,
            #     $False
            # );
        }
    }
}

DownloadBuildArtifacts
InstallUpdate