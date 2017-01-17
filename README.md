# OneBox Deploy

This repository contains PowerShell cmdlet for developers and administrators to deploy [Microsoft Dynamics 365 for Operations](https://ax.help.dynamics.com/en/) deployable runtime package.

## Supported environment

Cmdlet supposed to be ran in [OneBox](https://ax.help.dynamics.com/en/wiki/access-microsoft-dynamics-ax-7-instances-2/#vm-that-is-running-on-premises) topology used as on-premises Test environment, executed after a build is complete. Supported build definition is described in this article: [Developer topology deployment with continuous build and test automation](https://ax.help.dynamics.com/en/wiki/developer-topology-deployment-with-continuous-build-and-test-automation/)

## How it works

Recommended location is ```C:\Deploy\``` directory. 
* Package is downloaded from Visual Studio Team Services project; 
* Specified build definition is searched for latest successful build;
* If one found, it's artifacts are downloaded and unpacked;
* Rest of scenario is automation of the steps described in [Manual apply a deployable package](https://ax.help.dynamics.com/en/wiki/installing-deployable-package-in-ax7/) tutorial.

Script directory is a working directory. Following subdirectories are created on each run:

* ```<Build Definition>```
	* ```<Build Id>-<Timestamp>```
      * ```Packages```

```\Packages``` directory is a working directory for ```AXUpdateInstaller```

## Usage

* ```-username``` Visual Studio Online user name. Must be authorized to read build definitions and artifacts. 
* ```-accessToken``` [Personal access token](https://www.visualstudio.com/en-us/docs/integrate/get-started/auth/overview) used to authenticate for REST API call
* ```-vstsProjectUri``` Full URI pointing to project in such format: ```https://<account>.visualstudio.com/defaultcollection/<ProjectName>```
* ```-buildDefinitionName``` Build definition name
* ```-runbook``` Name of runbook that will be created or updated. If exists will be always overwritten.

Cmdlet potentially can be used as a task in release management, but there was no such intention and such scenario was not tested.

## Miscellaneous

This repo is inspired by [Azure DevTest Labs](https://github.com/Azure/azure-devtestlab) [Download and Run script](https://github.com/Azure/azure-devtestlab/tree/master/Artifacts/windows-vsts-download-and-run-script)





