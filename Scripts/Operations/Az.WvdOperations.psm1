#region completer scripblocks
$rgScriptBlock = {Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName}
$hpScriptBlock = {Get-AzWvdHostPool | Select-Object -ExpandProperty Name}
$subScriptBlock = {Get-AzSubscription | Select-Object -ExpandProperty Name}
$locScriptBlock = {Get-AzLocation | Select-Object -ExpandProperty Location}
#endregion

Function _WaitOnJobs {
    <#
        .SYNOPSIS
            Waits upto 60 minutes for background jobs to finish, otherwise, stops the jobs
        .DESCRIPTION
            Creates a while loop for running jobs. If a background job is running for longer than the -maxDuration, the job will be stopped to prevent an endless job loop.
    #>
    [CmdletBinding()]
    Param (
        # Array of current jobs
        [System.Collections.ArrayList]$Jobs = @(Get-Job),

        # Maximum number of minutes to allow the the jobs to run to completion
        [System.Int32]$maxDuration = 60
    )

    $timeSpan = [timespan]::FromMinutes($maxDuration)
    Write-Host ("Waiting on Jobs") -NoNewline
    While (($Jobs | Where-Object {$_.State -eq "Running"}).Count -gt 0) {
        $utcNow = [DateTime]::UtcNow
        Foreach ($Job in ($Jobs | Where-Object {$_.State -eq "Running"})) {
            If ($utcNow.Subtract($Job.PSBeginTime.ToUniversalTime()) -gt $timeSpan) {
                $Job | Stop-Job -Confirm:$false
            }
        }
        Write-Host (".") -NoNewline
        Start-Sleep -Milliseconds 2500
    }
    Write-Host ("Done!")
}

Function Show-Menu {
    <#
        .SYNOPSIS
            Shows a console based menu and title or just a console title banner in a variety of colors and stles.
        .DESCRIPTION
            Create a console based menu and use this function to display it with a descriptive title bar. This function is primarily used to display the title bar in a variety of colors and sytles. It is useful when used to convey important information to the console operator.
    #>
    Param (
        # Single line title or banner used as a desciption or message to the console operator
        [Parameter(Position=0,Mandatory=$true)]
        [System.String]$Title,

        # Console based menu with multiple selection options
        [Parameter(Position=1,Mandatory=$false)]
        [System.String]$Menu,

        # Allows for a variety of style selections and sizes, default style (full)
        [Parameter(Position=2,Mandatory=$false)]
        [ValidateSet("Full","Mini","Info")]
        [System.String]$Style = "Full",

        # Foreground text colors
        [Parameter(Position=3,Mandatory=$false)]
        [ValidateSet("White","Cyan","DarkCyan","Magenta","Yellow","DarkYellow","Green","DarkGreen","Red","DarkRed","Gray","DarkGray","Blue","DarkBlue")]
        [System.String]$Color = "Gray",

        # Clears the console screen before displaying the menu / title
        [Parameter(Position=4,Mandatory=$false)]
        [Switch]$ClearScreen,

        # Does not prompt for menu selection, shows the menu display only.
        [Parameter(Position=5,Mandatory=$false)]
        [Switch]$DisplayOnly
    )

    [System.Text.StringBuilder]$menuPrompt = ""
    Switch($Style) {
        "Full" {
            [Void]$menuPrompt.AppendLine("`n")
            [Void]$menuPrompt.AppendLine("/" * (95))
            [Void]$menuPrompt.AppendLine("////`n`r//// $Title`n`r////")
            [Void]$menuPrompt.AppendLine("/" * (95))
            [Void]$menuPrompt.AppendLine("`n")
        }
        "Mini" {
            [Void]$menuPrompt.AppendLine("`n")
            [Void]$menuPrompt.AppendLine("\" * (80))
            [Void]$menuPrompt.AppendLine(" $Title")
            [Void]$menuPrompt.AppendLine("\" * (80))
            [Void]$menuPrompt.AppendLine("`n") 
        }
        "Info" {
            [Void]$menuPrompt.AppendLine("`n")
            [Void]$menuPrompt.AppendLine("-" * (80))
            [Void]$menuPrompt.AppendLine("-- $Title")
            [Void]$menuPrompt.AppendLine("-" * (80))
            [Void]$menuPrompt.AppendLine("`n")
        }
    }

    #add the menu
    [Void]$menuPrompt.AppendLine($Menu)

    If ($ClearScreen) { [System.Console]::Clear() }

    If ($DisplayOnly) {Write-Host $menuPrompt.ToString() -ForegroundColor $Color}
    Else {
        [System.Console]::ForegroundColor($Color)
        Read-Host -Prompt $menuPrompt.ToString()
        [System.Console]::ResetColor()
    }
    
}

Function Get-ChoicePrompt {
    <#
        .SYNOPSIS
            Creates a customizable user prompt at the console.
        .DESCRIPTION
            This function will create a custom prompt with custom selections for the operator to make specific decisions or choices
    #>
    [CmdletBinding()]
    Param (
        # Array of strings for the options to be presented ("Yes","No" -or- "&Yes",&No"), use the '&' symbol as the designated letter for selection
        [Parameter(Mandatory = $true)]
        [String[]]$OptionList,

        # Title of the choice prompt
        [Parameter(Mandatory = $false)]
        [String]$Title,

        # Message to convey to the user / operator
        [Parameter(Mandatory = $False)]
        [String]$Message = $null,

        # Select the default choice (index based on the number of options)
        [int]$Default = 0 
    )
    $Options = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription] 
    $OptionList | ForEach-Object { $Options.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList $_)) } 
    $Host.ui.PromptForChoice($Title, $Message, $Options, $Default) 
}

Function Get-LatestWVDConfigZip {
    <#
        .SYNOPSIS
            Fetches the latest WVD Configuration zip file for WVD Deployments
        .DESCRIPTION
            This function takes no parameters and simply fetches the latest configuration zip file for WVD Deployments from the Microsoft WVD Product Group
    #>
    [xml]$results = (Invoke-WebRequest -Uri "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts?restype=container&comp=list").Content.Substring(3)
    If ($results.EnumerationResults.Blobs.Blob.Count -gt 0) {
        [System.Collections.ArrayList]$list = @()
        $x = $results.EnumerationResults.Blobs.Blob | Where-Object {$_.Name -like "Configuration_*"}
        $x | ForEach-Object {
            $dateindex = $_.Name.IndexOf("_")
            $config = $_ | Select-Object Url,@{l='Date';e={$_.Name.Substring($dateindex + 1).Split(".")[0] | Get-Date}}
            [void]$list.Add($config)
        }
        Return ($list | Sort-Object Date -Descending | Select-Object -First 1).Url
    }
    Else { Return "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration.zip" }
}

Function Enable-AzWvdMaintanence {
    <#
        .SYNOPSIS
            Puts a specific group of session hosts in a host pool into 'maintenance'
        .DESCRIPTION
            This function targets a specific host pool and group of session hosts, changes their Azure maintenance tag to TRUE and turns on drain mode to prevent new connections. Use of this function is for session host redeployment for monthly patching or session host recycling.
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="High")]
    Param (
        # Name of the Resource Group of the WVD Host Pool (supports tab completion)
        [Parameter(Mandatory=$true,Position=0)]
        [System.String]$ResourceGroupName,

        # Name of the WVD Host Pool (supports tab completion)
        [Parameter(Mandatory=$true,Position=1)]
        [System.String]$HostPoolName,

        # Group of Session Hosts to target (A or B)
        [Parameter(Mandatory=$true,Position=2)]
        [System.String]$SessionHostGroup
    )
    PROCESS {
        try {

            # logoff message sent to users with active sessions
            $Global:LogOffMessage = (@"
{0}
{1}
{1}  This virtual desktop is being prepared for maintenance.
{1}  If you would like to continue working, please LOGOFF and
{1}  then SIGN-IN again. Do NOT close the window / session
{1}  or simply disconnect.
{1}  
{1}  SHUTDOWN IN 5 MINUTES!
{1}
{0}
"@ -f ("/"*80),"//") # characters used to format the message prompt

            # collection the virtual machines based on WVD-Group tag
            Write-Verbose ("[{0}] Gathering Session Hosts from Group {1}" -f $HostPoolName,$SessionHostGroup)
            $vmCollection = Get-AzVM -ResourceGroupName $ResourceGroupName -Status | Where-Object {$_.Tags["WVD-Group"] -eq $SessionHostGroup}
            
            # loop through the virtual machines and add the session host information to the vm object
            $i = 0
            $sessionHostCount = 0
            Foreach ($virtualMachine in $vmCollection) {
                Write-Progress -Activity ("[{0}] Gathering Session Hosts from Group {1}" -f $HostPoolName,$SessionHostGroup.ToUpper()) -Status ("Session Hosts Collected: {0}" -f $sessionHostCount) -CurrentOperation $virtualMachine.Name -PercentComplete (($i / $vmCollection.Count) * 100)
                $sessionHost = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | Where-Object {$_.ResourceId -eq $virtualMachine.Id}
                
                If ($sessionHost) {
                    $sessionHostCount++
                    $virtualMachine | Add-Member -NotePropertyName SessionHost -NotePropertyValue $sessionHost
                }
                $i++
            }
            Write-Progress -Activity ("[{0}] Gathering Session Hosts from Group {1}" -f $HostPoolName,$SessionHostGroup.ToUpper()) -Completed

            Write-Warning ("PLEASE REVIEW THE COMMENT BASED HELP FOR THIS COMMAND - PROCEEDING WILL FORIBLY LOGOFF USERS AFTER A 5 MINUTE GRACE PERIOD!")

            # prevent this prompt by using -Confirm $false
            If ($PSCmdlet.ShouldProcess(("{0} WVD Session Hosts" -f $vmCollection.Count),"ENABLE maintenace and DRAIN current sessions")) {
                # loop through each vm in the collection, update the maintenance tag, turn on drain mode, and send all active users a log off message
                $x = 0
                $msgsSent = 0
                Foreach ($virtualMachine in $vmCollection) {
                    Write-Progress -Id 42 -Activity ("[{0}] Updating Maintenance Tag, Enabling Drain Mode and sending Logoff Message" -f $HostPoolName) -Status ("Session Hosts Updated: {0} | Messages Sent: {1}" -f $x,$msgsSent) -CurrentOperation $virtualMachine.SessionHost.Name -PercentComplete (($x / $vmCollection.Count) * 100)
                    $tagUpdate = @{"WVD-Maintenance" = $true}
                    Update-AzTag -ResourceId $virtualMachine.Id -Tag $tagUpdate -Operation Merge | Out-Null
                    Update-AzWvdSessionHost -Name $virtualMachine.SessionHost.Name.Split("/")[-1] -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -AllowNewSession:$false | Out-Null
                    $userSessions = Get-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SessionHostName $virtualMachine.sessionHost.Name.Split("/")[-1]
                    If ($userSessions) {
                        Foreach ($session in $userSessions.Where{$_.SessionState -ne "Disconnected"}) {
                            Write-Progress -ParentId 42 -Activity ("Sending Logoff Messages") -Status ("Sessions: {0}" -f $userSessions.Where{$_.SessionState -ne "Disconnected"}.Count)
                            Send-AzWvdUserSessionMessage `
                                -SessionHostName $virtualMachine.sessionHost.Name.Split("/")[-1] `
                                -ResourceGroupName $ResourceGroupName `
                                -HostPoolName $HostPoolName `
                                -MessageTitle "!! WARNING - SYSTEM MAINTENANCE !!" `
                                -MessageBody $Global:LogOffMessage `
                                -UserSessionId $session.Name.Split("/")[-1]
                            $msgsSent++
                        }
                        Write-Progress -ParentId 42 -Activity ("Sending Logoff Messages") -Completed
                    }
                    $x++
                }
                Write-Progress -Id 42 -Activity ("[{0}] Updating Maintenance Tag and Drain Mode" -f $HostPoolName) -Completed

                # 5 minute sleep timer to allow active users to save work and logoff - update these values to change the duration
                For ($i = 0; $i -lt 300; $i++) {
                    Write-Progress -Activity "WVD Session Logoff Stall Timer" -Status "Please wait..." -SecondsRemaining (300 - $i)
                    Start-Sleep -Milliseconds 999
                }
                Write-Progress -Activity "WVD Session Logoff Stall Timer" -Completed

                # collects the number of running vm(s) to determine which to stop
                $vmsOnline = ($vmCollection.Where{$_.PowerState -eq "VM running"} | Measure-Object).Count
                # prevent this prompt by using -Confirm $false
                If ($PSCmdlet.ShouldProcess(("{0} Running WVD Session Hosts" -f $vmsOnline),("STOP and DEALLOCATE Virtual Machines in Group {0}" -f $SessionHostGroup.ToUpper()))) {
                    
                    # loop through each running vm and initiate the stop command without waiting - no need to wait as the portal should be used to validate the vm state
                    Write-Host ("`n`r")
                    $vmCollection.Where{$_.PowerState -eq "VM running"} | Foreach-Object {
                        $shName = $_.SessionHost.Name
                        $_ | Stop-AzVm -NoWait -Force | Select-Object @{l="Session Host Name";e={$shName}},@{l="Group";e={$SessionHostGroup}},@{l="Stop VM Status";e={$_.IsSuccessStatusCode}}
                    } | Format-Table -Autosize
                    
                    Write-Host ("-" * 120) -ForegroundColor Green
                    Write-Host ("-- Attempted to STOP and DEALLOCATE {0} virtual machines. Please verify state for each VM in the Azure Portal." -f $vmsOnline) -ForegroundColor Green
                    Write-Host ("-" * 120) -ForegroundColor Green
                }
                Else { Write-Warning "User aborted Stop-AzVM operation!" }
            }
            Else { Write-Warning "User aborted WVD Maintenance operation!" }
        }
        catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }
}

Function Remove-AzWvdResources {
    <#
        .SYNOPSIS
            Removes session hosts from host pools and deletes Azure resources
        .DESCRIPTION
            This function is used after session hosts have been put into 'maintenance'. This will remove session hosts from host pools and delete the virtual machine. Optionally, you can delete the attached NIC(s) and Disk(s).
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="High")]
    Param (
        # Name of the Resource Group of the WVD Host Pool (supports tab completion)
        [Parameter(Mandatory=$true,Position=0)]
        [System.String]$ResourceGroupName,

        # Name of the WVD Host Pool (supports tab completion)
        [Parameter(Mandatory=$true,Position=1)]
        [System.String]$HostPoolName,

        # Group of Session Hosts to target (A or B)
        [Parameter(Mandatory=$true,Position=2)]
        [System.String]$SessionHostGroup,

        # Also removes nic(s) and disk(s)
        [Switch]$IncludeAttachedResources
    )
    PROCESS {
        try {
            # collection the virtual machines based on WVD-Group tag
            $vmCollection = Get-AzVM -ResourceGroupName $ResourceGroupName -Status | Where-Object {$_.Tags["WVD-Group"] -eq $SessionHostGroup}
            
            # loop through the virtual machines and add the session host information to the vm object
            $i = 0
            $sessionHostCount = 0
            Foreach ($virtualMachine in $vmCollection) {
                Write-Progress -Activity ("[{0}] Gathering Session Hosts from Group {1}" -f $HostPoolName,$SessionHostGroup.ToUpper()) -Status ("Session Hosts Collected: {0}" -f $sessionHostCount) -CurrentOperation $virtualMachine.Name -PercentComplete (($i / $vmCollection.Count) * 100)
                $sessionHost = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | Where-Object {$_.ResourceId -eq $virtualMachine.Id}
                
                If ($sessionHost) {
                    $sessionHostCount++
                    $virtualMachine | Add-Member -NotePropertyName SessionHost -NotePropertyValue $sessionHost
                }
                $i++
            }
            Write-Progress -Activity ("[{0}] Gathering Session Hosts from Group {1}" -f $HostPoolName,$SessionHostGroup.ToUpper()) -Completed

            # separate messages based on removing attached resources
            If ($IncludeAttachedResources) { $message = ("REMOVE and DELETE Session Host(s) and attached resources (VM, OsDisk, Nic)" -f $HostPoolName) }
            Else { $message = ("REMOVE and DELETE Session Host(s) and attached resources (VM ONLY)" -f $HostPoolName) }

            # prevent this prompt by using -Confirm $false
            If ($PSCmdlet.ShouldProcess(("{0} WVD Session Host(s)" -f $vmCollection.Count),$message)) {
                # loop through each vm in the collection, remove from host pool, delete the vm, and optionally delete the nic and os disk
                $i = 0
                [system.collections.ArrayList]$deleteResults = @()
                Foreach ($virtualMachine in $vmCollection) {
                    Write-Progress -Activity "WVD Session Host(s) Clean Up Operation" -Status ("Session Host: {0} ({1} of {2})" -f $virtualMachine.SessionHost.Name,$i,$vmCollection.Count) -CurrentOperation ("Removing Session Host from Host Pool") -PercentComplete (($i / $vmCollection.Count) * 100)
                    $shRemove = Remove-AzWvdSessionHost -Name $virtualMachine.SessionHost.Name.Split("/")[-1] -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Force
                    Write-Progress -Activity "WVD Session Host(s) Clean Up Operation" -Status ("Session Host: {0} ({1} of {2})" -f $virtualMachine.SessionHost.Name,$i,$vmCollection.Count) -CurrentOperation ("Deleting Azure Virtual Machine") -PercentComplete (($i / $vmCollection.Count) * 100)
                    $vmRemove = Remove-AzResource -ResourceId $virtualMachine.Id -Force
                    If ($IncludeAttachedResources) {
                        Write-Progress -Activity "WVD Session Host(s) Clean Up Operation" -Status ("Session Host: {0} ({1} of {2})" -f $virtualMachine.SessionHost.Name,$i,$vmCollection.Count) -CurrentOperation ("Deleting Azure Virtual Network Interface(s)") -PercentComplete (($i / $vmCollection.Count) * 100)
                        $nicRemove = $virtualMachine.NetworkProfile.NetworkInterfaces | ForEach-Object {Remove-AzResource -ResourceId $_.Id -Force}
                        Write-Progress -Activity "WVD Session Host(s) Clean Up Operation" -Status ("Session Host: {0} ({1} of {2})" -f $virtualMachine.SessionHost.Name,$i,$vmCollection.Count) -CurrentOperation ("Deleting Azure OS Disk") -PercentComplete (($i / $vmCollection.Count) * 100)
                        $diskRemove = Remove-AzResource -ResourceId $virtualMachine.StorageProfile.OsDisk.ManagedDisk.Id -Force
                    }
                    Else {
                        $nicRemove = "N/A"
                        $diskRemove = "N/A"
                    }
                    # creates an object with the results of the deletions for each vm and is collected into an array
                    $obj = [PSCustomObject][Ordered]@{
                        Resource = $virtualMachine.Name
                        "Remove Session Host" = $shRemove
                        "Remove Virtual Machine" = $vmRemove
                        "Remove Network Interface(s)" = $nicRemove
                        "Remove OS Disk" = $diskRemove
                    }
                    [Void]$deleteResults.Add($obj) # array of delete objects and statuses
                    $i++
                }
                Write-Progress -Activity "WVD Session Host(s) Clean Up Operation"  -Completed
                
                Write-Host ("`n`r")
                $deleteResults | Format-Table -Autosize # display the results on screen

                Write-Host ("-" * 120) -ForegroundColor Green
                Write-Host ("-- Attempted to REMOVE and DELETE {0} WVD Resources. Please validate using PowerShell or Azure Portal." -f $vmCollection.Count) -ForegroundColor Green
                Write-Host ("-" * 120) -ForegroundColor Green
            }
            Else { Write-Warning "User aborted clean up operation!" }

        }
        catch { $PSCmdlet.ThrowTerminatingError($PSItem) }
    }
}

Function New-AzWvdDeployment {
    <#
        .SYNOPSIS
            New WVD Deployment based on scale unit templates
        .DESCRIPTION
            This function will deploy any number of host pools and session hosts based on the scale unit template and parameter files. Before running this command, please be sure to understand all the prerequisites and have the parameters in the arm templates correctly defined.
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="Low")]
    Param(
        # Name of the Subscription for the WVD resources to be deployed (supports tab completion)
        [Parameter(Mandatory=$true,Position=0)]
        [System.String]$SubscriptionName,

        # Name of the Resource Group where the deployment should be created
        [Parameter(Mandatory=$true,Position=1)]
        [System.String]$DeploymentResourceGroup,

        # Name of the Subscription for the Storage Account with the artifacts and templates.  This parameter is optional based on the subscription of the Storage Account. (supports tab completion)
        [Parameter(Mandatory=$false,Position=2)]
        [System.String]$StorageAccountSubscription,

        # Name of the Resource Group of the Storage Account
        [Parameter(Mandatory=$true,Position=3)]
        [System.String]$StorageAccountResourceGroup,

        # Name of the Storage Account storing the artifacts and templates.
        [Parameter(Mandatory=$true,Position=4)]
        [System.String]$StorageAccountName,

        # Local path where the scale unit and parameter json files are stored.
        [Parameter(Mandatory=$true,Position=5)]
        [System.String]$TemplateFilePath,

        # Optional switch when used with GitHub self-hosted action runner
        [Switch]$SelfHosted
    )

    BEGIN {
        # sets the current path
        Push-Location -StackName CurrentPath
        # removes any previously run jobs if they exist
        If (@(Get-Job).Count -gt 0) { Get-Job | Remove-Job -Force }
        # checks for the WVD PowerShell module, force imports if exists, else installs and imports
        If (Get-InstalledModule Az.DesktopVirtualization) { Import-Module Az.DesktopVirtualization -Force }
        Else {
            Install-Module Az.DesktopVirtualization -Force -AllowClobber -Scope CurrentUser
            Import-Module Az.DesktopVirtualization -Force
        }

        # try / catch / finally blocks to validate path to JSON files
        try {
            If (Test-Path -Path $TemplateFilePath) {
                Set-Location $TemplateFilePath
                $Path = Get-Location | Select-Object -ExpandProperty Path
                $Files = Get-ChildItem -Path $Path -File
                If ($Files.Name -NotMatch "ScaleUnit") {
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::New(
                            [System.IO.DirectoryNotFoundException]"Cannot find scale unit JSON template files, check the path and try again.",
                            "MissingJSONFiles",
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            "TemplateFilePath"
                        )
                    )
                }
            }
            Else {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::New(
                        [System.IO.DirectoryNotFoundException]"TemplateFilePath not found, check the path and try again.",
                        "InvalidPath",
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        "TemplateFilePath"
                    )  
                )
            }
        }
        catch { Write-Output $PSItem }
        finally { Pop-Location -StackName CurrentPath }
    }
    PROCESS {
        Write-Host ("[{0}] Setting up inital variables..." -f (Get-Date))
        $expirationTime = (Get-Date).AddHours(24) # expiration time uses for SAS tokens and Host Pool registration token

        # connects to Azure based on self-hosted Github runner or regular console authentication
        Write-Host ("[{0}] Connecting to Azure Cloud..." -f (Get-Date))
        If ($SelfHosted) { $coreContext = Add-AzAccount -Identity -Subscription $StorageAccountSubscription }
        Else { $coreContext = Set-AzContext -Subscription $StorageAccountSubscription }
        
        $coreContext = Get-AzContext
        Write-Host ("`tConnected to: {0}, using {1}" -f $coreContext.Name.Split("(")[0].Trim(" "),$coreContext.Account.Id)

        # fetches the SAS URL(s) with tokens
        Write-Host ("[{0}] Generating Storage SAS Tokens and fetching various URL(s)..." -f (Get-Date))
        $stgAccountContext = (Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup -DefaultProfile $coreContext).Context
        $wvdHostPoolTemplateUri = New-AzStorageBlobSASToken -Container templates -Blob "Deploy-WVD-HostPool.json" -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        $wvdSessionHostTemplateUri = New-AzStorageBlobSASToken -Container templates -Blob "Deploy-WVD-SessionHosts.json" -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        
        $wvdContext = Set-AzContext -Subscription $subscriptionName
        Write-Host ("`tConnected to: {0}, using {1}" -f $wvdContext.Name.Split("(")[0].Trim(" "),$wvdContext.Account.Id)

        Write-Host ("[{0}] Starting WVD Scale Unit Deployment..." -f (Get-Date))
        $deploymentString = ([Guid]::NewGuid()).Guid.Split("-")[-1] # creates a unique deployment GUID
        # creates new deployment and stores the results into a variable
        $Results = New-AzResourceGroupDeployment `
            -Name ("Deploy-WVD-ScaleUnit-{0}" -f $deploymentString) `
            -ResourceGroupName $DeploymentResourceGrou `
            -wvd_hostPoolTemplateUri $wvdHostPoolTemplateUri `
            -wvd_sessionHostTemplateUri $wvdSessionHostTemplateUri `
            -wvd_deploymentString $deploymentString `
            -TemplateFile ("{0}\Deploy-WVD-ScaleUnit.json" -f $Path) `
            -TemplateParameterFile ("{0}\Deploy-WVD-ScaleUnit.parameters.json" -f $Path)

        If ($Results.ProvisioningState -eq "Succeeded") {
            Write-Host ("[{0}] WVD Scale Unit Deployment Succeeded!" -f $Results.Timestamp.ToLocalTime())
            [PSCustomObject]$Output = $Results.Outputs.Item("hostPoolsDeployed").Value.ToString() | ConvertFrom-Json # re-hydrates the JSON output from deployment
            $outputHash = $Output | Group-Object hostPoolName -AsHashTable -AsString # creates hashtable from the output

            $wvdDscConfigZipUrl = Get-LatestWVDConfigZip        

            # loops through each host pool deployment and creates a new deployment for WVD configuration (Log Analytics, Domain Join, DSC)
            [System.Collections.ArrayList]$deploymentJobs = @()
            Foreach ($hostPool in $outputHash.Keys) {

                # getting SAS tokens for template and parameter files
                $dscZipUri = New-AzStorageBlobSASToken -Container dsc -Blob $outputHash[$hostPool].dscConfiguration -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
                $DscTemplateUri = New-AzStorageBlobSASToken -Container templates -Blob "Deploy-WVD-Config.json" -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
                $DscTemplateParamUri = New-AzStorageBlobSASToken -Container templates -Blob "Deploy-WVD-Config.parameters.json" -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
                Invoke-WebRequest $DscTemplateParamUri | Select-Object -ExpandProperty Content | Out-File $env:TEMP\dsc.parameters.json -Force

                # getting WVD registration token
                Write-Host ("[{0}] Host Pool: {1} | Generating Host Pool registration token..." -f (Get-Date), $hostPool)
                $wvdHostPoolToken = New-AzWvdRegistrationInfo -ResourceGroupName $outputHash[$hostPool].resourceGroupName -HostPoolName $hostPool -ExpirationTime $expirationTime
                $vmNames = Get-AzVm -ResourceGroupName $outputHash[$hostPool].resourceGroupName | ForEach-Object {$_.Name}

                Write-Host ("[{0}] Host Pool: {1} | Starting WVD Session Host Configuration..." -f (Get-Date), $hostPool)
                # hashtable of parameters which are SPLATTED against the new deployment cmdlet
                $templateParams = [Ordered]@{
                    Name = ("Deploy-WVD-DscConfiguration-{0}" -f $deploymentString)
                    az_virtualMachineNames = $vmNames
                    wvd_dscConfigurationScript = $outputHash[$hostPool].dscConfiguration.Trim(".zip")
                    wvd_dscConfigZipUrl = $wvdDscConfigZipUrl
                    wvd_deploymentType = $outputHash[$hostPool].deploymentType
                    wvd_deploymentFunction = $outputHash[$hostPool].deploymentFunction
                    wvd_fsLogixVHDLocation = $outputHash[$hostPool].fsLogixVhdLocation
                    wvd_hostPoolName = $hostPool
                    wvd_hostPoolToken = $wvdHostPoolToken.Token
                    wvd_sessionHostDSCModuleZipUri = $dscZipUri
                    ResourceGroupName = $outputHash[$hostPool].resourceGroupName
                    TemplateUri = $DscTemplateUri
                    TemplateParameterFile = ("{0}\dsc.parameters.json" -f $env:TEMP)
                }
                
                $deploymentJob = New-AzResourceGroupDeployment @templateParams -AsJob
                [Void]$deploymentJobs.Add($deploymentJob)
            }

            # waits for the deployment jobs to finish (up to 1 hour)
            _WaitOnJobs -Jobs $deploymentJobs -maxDuration 60
            
            Get-Job | Group-Object State -NoElement
        }
        Else { Write-Host ("[{0}] WVD Scale Unit Deployment did not succeed - State: {1}" -f (Get-Date),$Results.ProvisioningState)}
    }
}

Function New-AzWvdSessionHosts {
    <#
        .SYNOPSIS
            New WVD Deployment based on scale unit templates
        .DESCRIPTION
            This function will deploy any number of host pools and session hosts based on the scale unit template and parameter files. Before running this command, please be sure to understand all the prerequisites and have the parameters in the arm templates correctly defined.
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="High")]
    Param (
        # Name of the Subscription for the WVD resources to be deployed (supports tab completion)
        [Parameter(Mandatory=$true,Position=0)]
        [System.String]$SubscriptionName,

        # Name of the Resource Group of the WVD Host Pool (supports tab completion)
        [Parameter(Mandatory=$true,Position=1)]
        [System.String]$ResourceGroupName,

        # Name of the WVD Host Pool (supports tab completion)
        [Parameter(Mandatory=$true,Position=2)]
        [System.String]$HostPoolName,

        # Group of Session Hosts to target (A or B)
        [Parameter(Mandatory=$true,Position=3)]
        [System.String]$SessionHostGroup,

        # Name of the Subscription for the Storage Account with the artifacts and templates.  This parameter is optional based on the subscription of the Storage Account. (supports tab completion)
        [Parameter(Mandatory=$false,Position=4)]
        [System.String]$StorageAccountSubscription,

        # Name of the Resource Group of the Storage Account
        [Parameter(Mandatory=$true,Position=5)]
        [System.String]$StorageAccountResourceGroup,

        # Name of the Storage Account storing the artifacts and templates.
        [Parameter(Mandatory=$true,Position=6)]
        [System.String]$StorageAccountName,

        # Name of the Resource Group for the Virtual Network.
        [Parameter(Mandatory=$true,Position=7)]
        [System.String]$VirtualNetworkResourceGroup,

        # Name of the Virtual Network.
        [Parameter(Mandatory=$true,Position=8)]
        [System.String]$VirtualNetworkName,

        [Parameter(Mandatory=$true,Position=9)]
        [Int]$NumberOfInstances
    )
    PROCESS {
        $expirationTime = (Get-Date).AddHours(24)

        # checking for storage account subscription for alternate context
        Write-Host ("[{0}] Connecting to Azure Subscription(s)..." -f (Get-Date))
        If ($StorageAccountSubscription) { $AzContext = Set-AzContext -Subscription $StorageAccountSubscription }
        Else { $AzContext = Set-AzContext -Subscription $subscriptionName }
        Write-Host ("`tConnected to: {0}, using {1}" -f $AzContext.Name.Split("(")[0].Trim(" "),$AzContext.Account.Id)

        # fetches the SAS URL(s) with tokens
        Write-Host ("[{0}] Generating Storage SAS Tokens and fetching various URL(s)..." -f (Get-Date))  
        $stgAccountContext = (Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup -DefaultProfile $AzContext).Context        
        $wvdSessionHostTemplateUri = New-AzStorageBlobSASToken -Container templates -Blob "Deploy-WVD-SessionHosts.json" -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        $wvdSessionHostTemplateParamUri = New-AzStorageBlobSASToken -Container templates -Blob "Deploy-WVD-SessionHosts.parameters.json" -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        Invoke-WebRequest $wvdSessionHostTemplateParamUri | Select-Object -ExpandProperty Content | Out-File $env:TEMP\sessionhost.parameters.json -Force
        $DscTemplateUri = New-AzStorageBlobSASToken -Container templates -Blob ("Deploy-WVD-Config.json") -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        $DscTemplateParamUri = New-AzStorageBlobSASToken -Container templates -Blob ("Deploy-WVD-Config.parameters.json") -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        Invoke-WebRequest $DscTemplateParamUri | Select-Object -ExpandProperty Content | Out-File $env:TEMP\dsc.parameters.json -Force
        
        # if using alternate context with storage account, switch to wvd subscription for remaining tasks
        If ($StorageAccountSubscription) {
            $wvdContext = Set-AzContext -Subscription $subscriptionName
            Write-Host ("`tConnected to: {0}, using {1}" -f $wvdContext.Name.Split("(")[0].Trim(" "),$wvdContext.Account.Id)
        }

        # collect host pool and network information
        $HostPool = Get-AzWvdHostPool -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName
        $vmTemplate = $HostPool.VMTemplate | ConvertFrom-Json
        $subnetId = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroup | Get-AzVirtualNetworkSubnetConfig -Name ("N2-Subnet-{0}" -f $HostPoolName.Split("-")[-1]) | Select-Object -ExpandProperty Id
        

        Write-Host ("[{0}] Starting WVD Session Host Deployment..." -f (Get-Date))
        $deploymentString = ([Guid]::NewGuid()).Guid.Split("-")[-1] # creates a unique deployment GUID
        # creates new deployment and stores the results into a variable
        $Results = New-AzResourceGroupDeployment `
            -Name ("Deploy-WVD-SessionHosts-Group-{0}-{1}" -f $SessionHostGroup,$deploymentString) `
            -ResourceGroupName $ResourceGroupName `
            -TemplateUri $wvdSessionHostTemplateUri `
            -TemplateParameterFile ("{0}\WvdParams.json" -f $env:TEMP) `
            -az_vmSize $vmTemplate.vmSize.Id `
            -az_vmNumberOfInstances $NumberOfInstances `
            -az_vmNamePrefix $vmTemplate.namePrefix `
            -az_vmImageOffer $vmTemplate.galleryImageOffer `
            -az_vmImagePublisher $vmTemplate.galleryImagePublisher `
            -az_vmImageSKU $vmTemplate.galleryImageSku `
            -az_vmDiskType $vmTemplate.osDiskType `
            -wvd_groupReference $SessionHostGroup `
            -wvd_buildVersion $HostPool.Tag["WVD-Build"] `
            -wvd_subnetId $subnetId `
            -wvd_hostpoolName $HostPoolName `

        If ($Results.ProvisioningState -eq "Succeeded") {
            Write-Host ("[{0}] WVD Session Host Deployment Succeeded!" -f $Results.Timestamp.ToLocalTime())

            # gets the latest WVD configuration zip from Microsoft
            $wvdDscConfigZipUrl = Get-LatestWVDConfigZip

            # gets the dsc zip URI in blob storage using SAS tokens
            $dscZipUri = New-AzStorageBlobSASToken -Container dsc -Blob ("{0}.zip" -f $HostPool.Tag["WVD-DscConfiguration"]) -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri

            # gets the host pool registration token
            Write-Host ("[{0}] Host Pool: {1} | Generating Host Pool registration token..." -f (Get-Date), $HostPoolName)
            $wvdHostPoolToken = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime $expirationTime
            
            # gets the list of vm(s) to redeploy post maintenance
            $vmNames = Get-AzVM -ResourceGroupName $ResourceGroupName -Status | Where-Object {$_.Tags["WVD-Group"] -eq $SessionHostGroup} | ForEach-Object {$_.Name}

            # hashtable of parameters which are SPLATTED against the new deployment cmdlet
            Write-Host ("[{0}] Host Pool: {1} | Starting WVD Session Host Configuration..." -f (Get-Date), $HostPoolName)
            $templateParams = [Ordered]@{
                Name = ("Deploy-WVD-DscConfiguration-{0}" -f $deploymentString)
                az_virtualMachineNames = $vmNames
                wvd_dscConfigurationScript = $HostPool.Tag["WVD-DscConfiguration"]
                wvd_dscConfigZipUrl = $wvdDscConfigZipUrl
                wvd_deploymentType = $HostPool.Tag["WVD-Deployment"]
                wvd_deploymentFunction = $HostPool.Tag["WVD-Function"]
                wvd_fsLogixVHDLocation = $HostPool.Tag["WVD-FsLogixVhdLocation"]
                wvd_hostPoolName = $HostPoolName
                wvd_hostPoolToken = $wvdHostPoolToken.Token
                wvd_sessionHostDSCModuleZipUri = $dscZipUri
                ResourceGroupName = $ResourceGroupName
                TemplateUri = $DscTemplateUri
                TemplateParameterFile = ("{0}\dsc.parameters.json" -f $env:TEMP)
            }
            
            New-AzResourceGroupDeployment @templateParams -AsJob | Out-Null
            
            # waits for the deployment jobs to finish (up to 1 hour)
            _WaitOnJobs
            
            Get-Job | Group-Object State -NoElement
        }
        Else { Write-Host ("[{0}] WVD Session Host Deployment did not succeed - State: {1}" -f (Get-Date),$Results.ProvisioningState)}
    }
}

Function New-AzWvdSessionHostConfig {
    <#
        .SYNOPSIS
            New WVD Session Host Configuration Deployment
        .DESCRIPTION
            This function should be used only when the session hosts in a host pool need to have the configuration redeployed. Typically, this would be run when the primary deployment fails during the configuration and the configuration may not have been deployed to all session hosts correctly.
    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="High")]
    Param (
        # Name of the Subscription for the WVD resources to be deployed (supports tab completion)
        [Parameter(Mandatory=$true,Position=0)]
        [String]$SubscriptionName,

        # Name of the Subscription for the Storage Account with the artifacts and templates.  This parameter is optional based on the subscription of the Storage Account. (supports tab completion)
        [Parameter(Mandatory=$false,Position=1)]
        [System.String]$StorageAccountSubscription,

        # Name of the Resource Group of the Storage Account
        [Parameter(Mandatory=$true,Position=2)]
        [System.String]$StorageAccountResourceGroup,

        # Name of the Storage Account storing the artifacts and templates.
        [Parameter(Mandatory=$true,Position=3)]
        [System.String]$StorageAccountName,

        # Azure region location of the resources and resource groups
        [Parameter(Mandatory=$true,Position=4)]
        [String]$Location
    )
    PROCESS {
        # creates and timestamp value for the SAS and host pool token values
        $expirationTime = (Get-Date).AddHours(24)

        # checking for storage account subscription for alternate context
        Write-Host ("[{0}] Connecting to Azure Subscription(s)..." -f (Get-Date))
        If ($StorageAccountSubscription) { $AzContext = Set-AzContext -Subscription $StorageAccountSubscription }
        Else { $AzContext = Set-AzContext -Subscription $subscriptionName }
        Write-Host ("`tConnected to: {0}, using {1}" -f $AzContext.Name.Split("(")[0].Trim(" "),$AzContext.Account.Id)

        # fetches the SAS URL(s) with tokens
        Write-Host ("[{0}] Generating Storage SAS Tokens and fetching various URL(s)..." -f (Get-Date))  
        $stgAccountContext = (Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $StorageAccountResourceGroup -DefaultProfile $AzContext).Context        
        $dscZipUri = New-AzStorageBlobSASToken -Container dsc -Blob ("{0}.zip" -f $DscConfiguration) -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        $DscTemplateUri = New-AzStorageBlobSASToken -Container templates -Blob ("Deploy-WVD-Config.json") -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        $DscTemplateParamUri = New-AzStorageBlobSASToken -Container templates -Blob ("Deploy-WVD-Config.parameters.json") -Protocol HttpsOnly -Permission r -StartTime (Get-Date) -ExpiryTime $expirationTime -Context $stgAccountContext -FullUri
        Invoke-WebRequest $DscTemplateParamUri | Select-Object -ExpandProperty Content | Out-File $env:TEMP\dsc.parameters.json -Force
        
        # if using alternate context with storage account, switch to wvd subscription for remaining tasks
        If ($StorageAccountSubscription) {
            $wvdContext = Set-AzContext -Subscription $subscriptionName
            Write-Host ("`tConnected to: {0}, using {1}" -f $wvdContext.Name.Split("(")[0].Trim(" "),$wvdContext.Account.Id)
        }
        
        [System.Collections.ArrayList]$deploymentJobs = @() # empty array for the deployment job
        # loop for menu system to select resource groups and host pools
        Do {
            # building the menu of available resource groups
            Write-Verbose "Getting WVD Resource Groups..."
            $RGs = Get-AzResourceGroup -Location $Location -Verbose:$false -Debug:$false | ForEach-Object {$_.ResourceGroupName} | Sort-Object
            Write-Verbose ("Found {0} Azure WVD Resource Groups" -f $RGs.Count)
            $RGSelection = (@"
`n
"@)
            $RGRange = 0..($RGs.Count - 1)
            For ($i = 0; $i -lt $RGs.Count;$i++) {$RGSelection += " [$i] $($RGs[$i])`n"}
            $RGSelection += "`n Please select a Resource Group"

            Do {$RGChoice = Show-Menu -Title "Select an Azure WVD Resource Group" -Menu $RGSelection -Style Full -Color White -ClearScreen}
            While (($RGRange -notcontains $RGChoice) -OR (-NOT $RGChoice.GetType().Name -eq "Int32"))
            
            Clear-Host
            Write-Host ("Selected WVD Resource Group: {0}" -f $RGs[$RGChoice])
            
            $HostPool = Get-AzWvdHostPool -ResourceGroupName $RGs[$RGChoice]
            If ($HostPool.Count -eq 1) {
                Write-Host ("Host Pool: {0}" -f $HostPool.Name)
                Write-Host ("Host Pool: {0} | Generating Host Pool registration token and fetch Configuration URL(s)" -f $HostPool.Name)

                # collecting properties from the existing host pool deployment
                $DscConfiguration = $HostPool.Tag["WVD-DscConfiguration"]
                $FsLogixVhdLocation = $HostPool.Tag["WVD-FsLogixVhdLocation"]
                $wvdHostPoolToken = New-AzWvdRegistrationInfo -ResourceGroupName $RGs[$RGChoice] -HostPoolName $HostPool.Name -ExpirationTime $expirationTime
                $vmNames = Get-AzVm -ResourceGroupName $RGs[$RGChoice] | ForEach-Object {$_.Name}

                Write-Host ("Host Pool: {0} | Starting WVD Session Host Configuration (AsJob)..." -f $HostPool.Name)
                $deploymentString = ([Guid]::NewGuid()).Guid.Split("-")[-1] # creates a unique deployment GUID
                $templateParams = [Ordered]@{
                    Name = ("Deploy-WVD-DscConfiguration-{0}" -f $deploymentString)
                    az_virtualMachineNames = $vmNames
                    wvd_dscConfigurationScript = $DscConfiguration
                    wvd_dscConfigZipUrl = $wvdDscConfigZipUrl
                    wvd_deploymentType = $HostPool.Tag["WVD-Deployment"]
                    wvd_deploymentFunction = $HostPool.Tag["WVD-Function"]
                    wvd_fsLogixVHDLocation = $FsLogixVhdLocation
                    wvd_hostPoolName = $HostPool.Name
                    wvd_hostPoolToken = $wvdHostPoolToken.Token
                    wvd_sessionHostDSCModuleZipUri = $dscZipUri
                    ResourceGroupName = $RGs[$RGChoice]
                    TemplateUri = $DscTemplateUri
                    TemplateParameterFile = ("{0}\dsc.parameters.json" -f $env:TEMP)
                }

                If ($PSCmdlet.ShouldProcess($HostPool.Name,"Initiate DSC Configuration Deployment")) {
                    $deploymentJob = New-AzResourceGroupDeployment @templateParams -AsJob
                    [Void]$deploymentJobs.Add($deploymentJob)
                    Write-Host ("Active Deployment Jobs: {0}" -f $deploymentJobs.Count)
                }
                Else {Write-Host "Configuration cancelled!"}
            }
            Else { Write-Warning ("Too many WVD Host Pools found in {0}" -f $RGs[$RGChoice])}
                    
            $Done = Get-ChoicePrompt -Title "`n" -Message "Select another WVD Resource Group?" -OptionList "&Yes","&No"
        } Until ($Done -eq 1)

        If ($deploymentJobs.Count -gt 0) {
            Show-Menu -Title "WVD Configuration Deployments" -DisplayOnly -ClearScreen -Color White -Style Info
            _WaitOnJobs -Jobs $deploymentJobs -maxDuration 60
        }
    }
}

#region register argument completers
Register-ArgumentCompleter -CommandName Enable-AzWvdMaintanence -ParameterName ResourceGroupName -ScriptBlock $rgScriptBlock
Register-ArgumentCompleter -CommandName Enable-AzWvdMaintanence -ParameterName HostPoolName -ScriptBlock $hpScriptBlock
Register-ArgumentCompleter -CommandName Remove-AzWvdResources -ParameterName ResourceGroupName -ScriptBlock $rgScriptBlock
Register-ArgumentCompleter -CommandName Remove-AzWvdResources -ParameterName HostPoolName -ScriptBlock $hpScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHostConfig -ParameterName SubscriptionName -ScriptBlock $subScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHostConfig -ParameterName Location -ScriptBlock $locScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdDeployment -ParameterName SubscriptionName -ScriptBlock $subScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdDeployment -ParameterName StorageAccountSubscription -ScriptBlock $subScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHosts -Parametername SubscriptionName -ScriptBlock $subScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHosts -Parametername ResourceGroupName -ScriptBlock $rgScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHosts -Parametername HostPoolName -ScriptBlock $hpScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHostConfig -Parametername SubscriptionName -ScriptBlock $subScriptBlock
Register-ArgumentCompleter -CommandName New-AzWvdSessionHostConfig -Parametername StorageAccountSubscription -ScriptBlock $subScriptBlock
#endregion