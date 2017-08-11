$nsgName = "YOUR_NSG_NAME"
$rsgName = "YOUR_RESOURCE_GROUP_NAME"
$subscriptionId = "YOUR_SUBSCRIPTION_ID"
# Get the raw file: 
Invoke-WebRequest -uri https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/master/articles/application-insights/app-insights-ip-addresses.md -OutFile appInsightsIps.txt
<#
 # You can add locations here, to construct the format you need from the locations listed above:
 # 1. Replace the : with a -
 # 2. Remove all Spaces
 # As an example: 
 # * US : CA-San Jose becomes US-CA-SanJose
 # * AU : Sydney becomes AU-Sydney
 #>
$requestedLocations = @("US-CA-SanJose", "US-IL-Chicago", "US-TX-SanAntonio", "US-VA-Ashburn", "US-FL-Miami")
$currentFile = ""
$ipLocations = @{}
foreach ($line in Get-Content .\appInsightsIps.txt)
{
  if ($line -match "\w{2} : \w+")
  {
    $currentFile = $line.Replace(":", "-").Replace(" ", "")
    write-output $currentFile
    write-output $line
    $ipLocations.Add($currentFile, @())

    continue
  }
  if ($line -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")
  {
    $ipLocations[$currentFile] += $line
    Write-Output $line
    continue
  }

}

#log into azure
Login-AzureRmAccount -SubscriptionId $subscriptionId
$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $rsgName -Name $nsgName
#Remove all Rules starting with "monitoring"
# If your current rules don't start with 'monitoring' then you can change this regex
# This tool prefixes all rules with 'monitoring' you can adjust that below
# or just switch this regex back after your first run
$monRules = $nsg.SecurityRules | Where-Object {$_.Name -match "^monitoring"}
foreach ($r in $monRules)
{
  Remove-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $r.Name
}
#commit the removal
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg

$ruleBase = 1000
foreach ($l in $requestedLocations)
{
  $nameBase = 01
  foreach ($ip in $ipLocations[$l])
  {
    Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "monitoring-$l-https$nameBase" -Description "allow monitoring from $l-$ip (https)" -Access Allow -Protocol Tcp -Direction Inbound -Priority $ruleBase -SourceAddressPrefix "$ip/32" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
    $ruleBase++
    Add-AzureRmNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "monitoring-$l-http$nameBase" -Description "allow monitoring from $l-$ip (https)" -Access Allow -Protocol Tcp -Direction Inbound -Priority $ruleBase -SourceAddressPrefix "$ip/32" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
    $ruleBase++
    $nameBase++
  }
}
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg
Write-Output $ipLocations