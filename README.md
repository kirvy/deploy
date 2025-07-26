# Dynamics 365 Package Installer Module

This PowerShell module provides a function to automate the installation of a pre-downloaded Microsoft Dynamics 365 deployable package. It is intended for use in cloud-hosted development or test environments.

The script wraps the `AXUpdateInstaller` to generate and execute a deployment runbook, automating the steps described in the [Install deployable packages from the command line](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/deployment/install-deployable-package) tutorial.

## Prerequisites

Before using this module, you must have a deployable package downloaded and unpacked into a single directory. This directory is the working directory for the `AXUpdateInstaller`. It must contain:

*   The AX Update Installer files (e.g., `AXUpdateInstaller.exe`, `Microsoft.Dynamics.AX.AXUpdateInstallerBase.dll`).
*   The topology and service model data files (`DefaultTopologyData.xml`, `DefaultServiceModelData.xml`).
*   The hotfix installation information (`HotfixInstallationInfo.xml`).

## Usage

1.  Open a PowerShell console and navigate to the directory containing the module.
2.  Import the module:
    ```powershell
    Import-Module -Name .\InstallModule.psm1
    ```
3.  Execute the installation function, pointing it to your artifacts directory:
    ```powershell
    Install-AXUpdate -ArtifactsDir "C:\Path\To\Your\Unpacked\Package" -RunBook "MyDeploymentRunbook"
    ```

### Parameters

*   `-ArtifactsDir` (string, Mandatory): The full path to the directory containing the unpacked deployable package and all required installer files.
*   `-RunBook` (string, Mandatory): The name for the deployment runbook that will be generated and executed. If a runbook with this name already exists, it will be overwritten.





