jenv PowerShell Edition
=======================================
jenv is a tool for managing parallel Versions of Java Development Kits, please visit http://jenv.io for detail.
jenv-ps is a PowerShell Edition for jenv.

### Install
Execute following command In your PowerShell console:

     (new-object Net.WebClient).DownloadString("http://get.jenv.io/GetJenv.ps1") | iex

You can use 'jenv selfupdate' to update jenv itself.

### Commands

* install: Install candidate, such as jenv install maven 3.2.1
* default: make the version as default for candidate, such as jenv default java 1.8.0_05
* use: switch to a version for candidate, such as jenv use maven 3.1.1
* list: list the candidate versions, such as jenv list maven
* repoupdate: update jenv central repo

### Development
Editor: PowerGUI Script Editor, VCS: Git. Steps as following: 

    set-executionpolicy remotesigned
    git clone  git@github.com:linux-china/jenv-ps.git  C:\Users\xxxxx\Documents\WindowsPowerShell\Modules\jenv
    Get-Module -ListAvailable
    Import-Module -Verbose -Name jenv

Modify c:\Users\xxx\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1  add "jenv init"

### Todo 

* local repository support
* default version for candidate
* code completion
* Document
