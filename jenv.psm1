$jenvDir = $Env:JENV_DIR

if(! $jenvDir) {
  $jenvDir="c:\jenv"
}

function Update-Path([string]$candidate, [string]$candidateHome){ 
    $tempPath=$Env:Path
	if($tempPath.Contains("$jenvDir\candidates\$candidate")) {
	   $regex="$jenvDir\candidates\$candidate".Replace('\',"\\");
	   $tempPath = $tempPath -replace "$regex[^;]*;", ""
	}
    $Env:Path = $candidateHome +"\bin;"+$tempPath
    [environment]::SetEnvironmentVariable($candidate.ToUpper()+"_HOME", $candidateHome,"Process")
}

function Initialize-Jenv() {
   $shell = New-Object -COM WScript.Shell
   $candidatesHome = "$jenvDir\candidates"
   if ( !(Test-Path $candidatesHome) ) {
       New-Item -ItemType Directory $candidatesHome | Out-Null
    }
   $files = dir $candidatesHome
   for($i=0;$i –lt $files.Length;$i++){
     $candidate=$files[$i].Name
	 $candidateLink="$jenvDir\candidates\$candidate\current.lnk"
	 if ( Test-Path "$jenvDir\candidates\$candidate\current.lnk") {
	     $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
		 if( Test-Path $link.TargetPath ) {
		   Update-Path $candidate $link.TargetPath
		 }
	 }
   }
}

function jenv([string]$Command, [string]$Candidate, [string]$Versiond)
{
     try {
        switch ($Command) {
		    'init'          { Initialize-Jenv }
			'all'           { Show-All }
            'help'          { Show-Help }
			'install'       { Install-Candidate $Candidate $Versiond }
			'default'       { Select-Candidate $Candidate $Versiond }
			'uninstall'     { Uninstall-Candidate $Candidate $Versiond }
			'use'           { Use-Candidate $Candidate $Versiond }
			'cd'            { Enter-Candidate $Candidate $Versiond }
			'current'       { Get-CurrentCandidate $Candidate }
			'list'          { if($Candidate) { List-Candidate $Candidate  } else { List-Installs  }  }
			'repoupdate'    { Update-Repo }
			'selfupdate'    { Update-Jenv }
            default         { Write-Warning "Invalid command: $Command"; Show-Help }
        }
    } catch {
        Show-Help
    }
}

function Install-Candidate([string]$candidate, [string]$version){
    $jenvArchives="$jenvDir\archives"
	if ( !(Test-Path $jenvArchives )) {
      New-Item $jenvArchives -ItemType Directory | Out-Null
    }
	$candidateFileName=$candidate+"-"+$version+".zip"
	$candidateHome="$jenvDir\candidates\$candidate\$version"
	if ( !(Test-Path $candidateHome )) { 
		if ( !(Test-Path "$jenvArchives\$candidateFileName")) {
		  Write-Output "Begin to install $candidate($version)"
		  $osArch="x86"
		  $OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
   		  if ($OSArchitecture.Contains("64")) {
    		 $osArch="x86_64"
          }
		  $candidateUrl="http://jenv.mvnsearch.org/candidate/$candidate/download/$version/Cygwin/$osArch"
		  Write-Output "Parsing $candidateUrl"
          $downloadUrl=(new-object Net.WebClient).DownloadString($candidateUrl)
	      if ( !(Test-Path "$jenvDir\candidates\$candidate" )) {
	         New-Item "$jenvDir\candidates\$candidate" -ItemType directory | Out-Null
	      }
		  if( !($downloadUrl.StartsWith("http://"))) {
		        Write-Output $candidate
				return
		  }
		  Write-Output "Download Candidate from $downloadUrl"
		  $webClient = (New-Object Net.WebClient)
		  $webClient.DownloadFile($downloadUrl, "$jenvArchives\$candidateFileName")
		}
		# unzip archive
		$shell = New-Object -com shell.application
		$shell.namespace($jenvArchives).copyhere($shell.namespace("$jenvArchives\$candidateFileName").items(), 0x14)
		Move-Item ("$jenvArchives\"+$candidate+"-"+$version) ($candidateHome)
		Write-Output "$candidate($version) installed!"
		Select-Candidate $candidate $version
	}
}

function Select-Candidate([string]$candidate, [string]$version){ 
    $shell = New-Object -COM WScript.Shell
	$candidateHome="$jenvDir\candidates\$candidate\$version"
	$candidateLink="$jenvDir\candidates\$candidate\current.lnk"
	if ( Test-Path $candidateHome) { 
		if ( Test-Path $candidateLink) { 
		    Remove-Item $candidateLink | Out-Null
		}
		$link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
		$link.TargetPath=$candidateHome
	    $link.Save()
		Update-Path $candidate $candidateHome
		Write-Output "Using $candidate($version) in this shell"
	}else {
	    Write-Output "$candidate($version) not installed on local host"
	}
}

function List-Candidate([string]$candidate){ 
    $shell = New-Object -COM WScript.Shell
	$candidateHome="$jenvDir\candidates\$candidate";
	$defaultVersionHome=""
	$candidateLink="$candidateHome\current.lnk"
	if ( Test-Path $candidateLink) { 
		  $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
		  $defaultVersionHome = $link.TargetPath
	}
	$link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
    Write-Output "Avaliable $candidate Versions"
	Write-Output "====================================="
	$content = Get-Content "$jenvDir\repo\central\version\$candidate.txt"
    $versions = $content.Split(" ")
	# installed versions
	if ( Test-Path $candidateHome) {
		$installedVersions =  (dir $candidateHome)
	    foreach ($version in $installedVersions)  {
	      if(!($version.Name.EndsWith(".lnk"))) {
		     if(!($versions  -contains $version.Name)) {
			    $versions += $version.Name 
			 }
		  }
	    }
	}
    foreach ($version in $versions) 
    {
	   $versionHome ="$jenvDir\candidates\$candidate\$version"
	   if ( Test-Path $versionHome) { 
	       if($versionHome -eq $defaultVersionHome) {
		      Write-Output ">* $version"
		   } else { 
		      Write-Output " * $version"
		   }
	   } else {
        Write-Output "   $version"
	   }
    }
}

function List-Installs(){ 
    $candidatesHome ="$jenvDir\candidates\"
	Write-Output "Candidates installed on localhost"
	if ( Test-Path $candidatesHome) {
	    $candidates = (dir $candidatesHome)
		foreach ($candidate in $candidates)  {
		    $candidateName = $candidate.Name
		    $installedVersions =  (dir "$candidatesHome\$candidateName")
			Write-Output "$candidateName"
		    foreach ($version in $installedVersions)  {
		      if(!($version.Name.EndsWith(".lnk"))) {
				    $versionName= $version.Name 
					Write-Output "  $versionName"
			  }
		    }
		}
	}
}

function Use-Candidate([string]$candidate, [string]$version){
	$candidateHome="$jenvDir\candidates\$candidate\$version"
	if ( Test-Path $candidateHome) { 
		Update-Path $candidate $candidateHome
		Write-Output "$candidate swithed to $version"
	}else {
	    Write-Output "$candidate($version) not installed on localhost"
	}
}

function Uninstall-Candidate([string]$candidate, [string]$version){  
   $candidateHome="$jenvDir\candidates\$candidate\$version"
   if ( (Test-Path $candidateHome)) {
       Remove-Item -Recurse -Force $candidateHome 
	   $candidateFileName=$candidate+"-"+$version+".zip"
	   Remove-Item "$jenvDir\archives\$candidateFileName"
   }
   Write-Output "$candidate($version) uninstalled"
}

function Enter-Candidate([string]$candidate, [string]$version){  
   $candidateHome="$jenvDir\candidates\$candidate\$version"
   if(  $version -le $null) {
        $candidateLink="$jenvDir\candidates\$candidate\current.lnk"
		if ( Test-Path $candidateLink) { 
		     $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
			 $candidateHome=$link.TargetPath
		}
   }
   if ( Test-Path $candidateHome) {
       cd $candidateHome
   }
}

function Update-Repo() {
   $downloadUrl="http://jenv.mvnsearch.org/info.zip?osName=Cygwin&platform=x64"
   $webClient = (New-Object Net.WebClient)
   $webClient.DownloadFile($downloadUrl, "$jenvDir\temp\central-repo.zip")

   $shell = New-Object -com shell.application
   New-Item -ItemType Directory "$jenvDir\temp\central" | Out-Null
   $shell.namespace("$jenvDir\temp\central").copyhere($shell.namespace("$jenvDir\temp\central-repo.zip").items(), 0x14)
   Remove-Item -Recurse -Force "$jenvDir\repo\central"
   Move-Item ("$jenvDir\temp\central") ("$jenvDir\repo")
   Remove-Item -Recurse -Force "$jenvDir\temp\central-repo.zip"
   Write-Output "Repo updated"
}

function Show-All() {
  	type "$jenvDir\repo\central\candidates.txt"
}

function Get-CandidateVersion([string]$candidate, [string]$version){  
   $candidateHome="$jenvDir\candidates\$candidate\$version"
   if(  $version -le $null) {
        $candidateLink="$jenvDir\candidates\$candidate\current.lnk"
		if ( Test-Path $candidateLink) { 
		     $link = $shell.CreateShortcut("$jenvDir\candidates\$candidate\current.lnk")
			 $candidateHome=$link.TargetPath
		}
   }
   if ( Test-Path $candidateHome) {
       cd $candidateHome
   }
}

function Get-CurrentCandidate([string]$candidate){  
   $candidateHome=[environment]::GetEnvironmentVariable($candidate.ToUpper()+"_HOME","Process")
   Write-Output $candidateHome
}

function Update-Jenv(){  
  $jenvZipUrl = 'http://get.jenv.io/jenv-ps.zip'
  $modulePaths = @($Env:PSModulePath -split ';')
  $targetModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
  $jenvPath = "$targetModulePath\jenv"
  try {
    # create temp dir
    $tempDir = [guid]::NewGuid().ToString()
    $tempDir = "$env:TEMP\$tempDir"
    New-Item -ItemType Directory $tempDir | Out-Null

    # download current version
    $jenvZip = "$tempDir\jenv.zip"
    Write-Host "Downloading jenv"
    $client = (New-Object Net.WebClient)
    $client.DownloadFile($jenvZipUrl, $jenvZip)

    # unzip archive
    $shell = New-Object -com shell.application
    $shell.namespace($tempDir).copyhere($shell.namespace($jenvZip).items(), 0x14)
	Copy-Item "$tempDir\jenv\*" $jenvPath -Force -Recurse
    Write-Host "jenv updated!" -Foreground Green		
	Import-Module -Name $jenvPath
  } finally {
    Remove-Item -Recurse -Force $tempDir
  }
}

function Show-Help() {
    Write-Output @"
Usage: jenv <command> <candidate> [version]

    commands:
        all                               
        list          <candidate> <version>
        install       <candidate> [version]
        uninstall     <candidate> <version>
        use           <candidate> [version]
        default       <candidate> [version]
        current       <candidate>         
        help                               
        repoupdate                                 
        selfupdate

eg: jenv install maven 3.2.1
"@
}

Export-ModuleMember -Function jenv

jenv "init"
