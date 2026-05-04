# Dynamics 365 Package Installer Module

This PowerShell module provides a function to automate the installation of a Microsoft Dynamics 365 deployable package. It is intended for use in Cloud-Hosted Environments.

The script wraps the `AXUpdateInstaller` to generate and execute a deployment runbook, automating the steps described in the [Install deployable packages from the command line](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/deployment/install-deployable-package) tutorial.

## Prerequisites

Before using this module, you must have a deployable package downloaded and unpacked into a single directory. This directory is the working directory for the `AXUpdateInstaller`. It must contain:

* The AX Update Installer files (e.g., `AXUpdateInstaller.exe`, `Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll`).
* The topology and service model data files (`DefaultTopologyData.xml`, `DefaultServiceModelData.xml`).
* The hotfix installation information (`HotfixInstallationInfo.xml`).

## Usage

1.  Open a PowerShell console and navigate to the unpacked deployable package directory.
2.  Import the module:
    ```powershell
    Import-Module -Name C:\Path\To\Module\Deploy\InstallModule.psm1
    ```
3.  Execute the installation function:
    ```powershell
    Install-AXUpdate
    ```

By default, `Install-AXUpdate` uses the current directory as the artifacts directory and creates a runbook named `axupdate`.

You can still provide explicit values when needed:

```powershell
Install-AXUpdate -ArtifactsDir "C:\Path\To\Your\Unpacked\Package" -RunBook "MyDeploymentRunbook"
```

### Parameters

*   `-ArtifactsDir` (string, Optional): The full path to the directory containing the unpacked deployable package and all required installer files. Defaults to the current directory.
*   `-RunBook` (string, Optional): The name for the deployment runbook that will be generated and executed. Defaults to `axupdate`. If a runbook with this name already exists, it will be overwritten.
*   `-WhatIf` (switch, Optional): Shows what would happen without generating, importing, or executing the runbook.
*   `-Verbose` (switch, Optional): Shows the resolved artifacts directory, runbook name, runbook file path, and deployment progress.

### Troubleshooting

If `Add-Type` fails with `HRESULT: 0x80131515`, Windows is blocking one or more downloaded installer assemblies. Review the package source, then unblock the extracted installer files from the package directory:

```powershell
Get-ChildItem -File -Recurse | Where-Object { $_.Extension -in '.dll', '.exe' } | Unblock-File
```

If `Generate` fails with `Assembly.get_Evidence()`, make sure you are running Windows PowerShell 5.1 instead of PowerShell 7+:

```powershell
powershell.exe -NoProfile
```




