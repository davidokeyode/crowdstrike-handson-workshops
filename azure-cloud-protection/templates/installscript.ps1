param (
    $UserName  
)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart 
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart

$env:chocolateyVersion = '1.4.0'
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

New-LocalGroup -Name docker-users -Description "Users of Docker Desktop"
Add-LocalGroupMember -Group 'docker-users' -Member $UserName

choco install docker-desktop git zip unzip vscode azure-cli dotnetcore-sdk httpie microsoftazurestorageexplorer 7zip.install googlechrome setdefaultbrowser win-no-annoy -y

SetDefaultBrowser.exe HKLM "Google Chrome" 

$trig = New-ScheduledTaskTrigger -AtLogOn 
$task = New-ScheduledTaskAction -Execute "C:\Program Files\Docker\Docker\Docker Desktop.exe" 
Register-ScheduledTask -TaskName start-docker -Force -Action $task -Trigger $trig -User $UserName

#Trigger a restart to enable hyper-v and containers
Restart-Computer -Force