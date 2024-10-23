########################################################################################################################
#                                                                                                                      #
#                                                                                                                      #
#                     Script to identify invalid ip reservatin on DHCP servers                                         #
#                                                                                                                      #
########################################################################################################################                                                                                                                     


$dhcpServer = Read-Host "Please enter the DHCP Server Name"

#Function to list the DHCP Scopes
function List-DhcpScope {
    param(
        [string]$DhcpServerName
    )

    Write-Host "Getting DHCP scopes from server: $DhcpServerName"

  
    $scopes = Get-DhcpServerv4Scope -ComputerName $DhcpServerName | Select-Object ScopeId, Name

    
    if ($scopes) {
        foreach ($scope in $scopes) {
            Write-Host "Scope ID: $($scope.ScopeId), Name: $($scope.Name)"
        }
    } else {
        Write-Host "No DHCP scopes found on server: $DhcpServerName"
    }
}

List-DhcpScope -DhcpServerName $dhcpserver



$scopeId = Read-Host "Please enter the DHCP Scope ID"
$dnsserver=(Get-DnsClientServerAddress).serveraddresses[0]
#$dnsServer = Read-Host "Please enter the DNS Server Name"


#Function to check whether DNS is resolving 
function Test-DnsResolution {
    param (
        [string]$ip,
        [string]$dnsServer
    )
    try {
       
        if (Resolve-DnsName -Server $dnsServer -Name $ip -ErrorAction SilentlyContinue )
        {
        return $true
        }
    } catch {
        return $false
    }
}


#Fucntion to do a ping test
function Test-Ping {
    param (
        [string]$ip
    )
    try {
        $pingResult = Test-Connection -ComputerName $ip -Count 1 -Quiet
        return $pingResult
    } catch {
        return $false
    }
}


$reservations = Get-DhcpServerv4Reservation -ComputerName $dhcpServer -ScopeId $scopeId


$tableRows = @()


foreach ($reservation in $reservations) {
    $ipAddress = $reservation.IPAddress
    $clientName = $reservation.Name
    $macAddress = $reservation.ClientId

    
    $dnsResult = Test-DnsResolution -ip $ipAddress -dnsServer $dnsServer

    
    $pingResult = Test-Ping -ip $ipAddress

    
    $dnsStatus = if ($dnsResult) { "<td style='background-color:green;'>DNS Resolved</td>" } else { "<td style='background-color:red;'>DNS Failed</td>" }
    $pingStatus = if ($pingResult) { "<td style='background-color:green;'>Ping Success</td>" } else { "<td style='background-color:red;'>Ping Failed</td>" }

    
    if ($dnsResult -or $pingResult) {
        $overallStatus = "<td style='background-color:green;'>Valid</td>"
    } else {
        $overallStatus = "<td style='background-color:red;'>Invalid</td>"
    }


    $row = "<tr>
                <td>$clientName</td>
                <td>$ipAddress</td>
                <td>$macAddress</td>
                $dnsStatus
                $pingStatus
                $overallStatus
            </tr>"
   
    $tableRows += $row
}


$htmlReport = @"
<html>
<head>
    <style>
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h2>DHCP Reservation Validation Report (Scope_ID) $($scopeid)</h2>
    <table>
        <tr>
            <th>Client Name</th>
            <th>IP Address</th>
            <th>MAC Address</th>
            <th>DNS Status</th>
            <th>Ping Status</th>
            <th>Overall Status</th>
        </tr>
        $($tableRows -join "`n")
    </table>
</body>
</html>
"@

#html file will be saved to logged in users desktop
$reportFilePath = "$env:USERPROFILE\Desktop\DHCP_Reservation_Report_$scopeId.html"
$htmlReport | Out-File -FilePath $reportFilePath -Encoding UTF8


Start-Process $reportFilePath

Write-Host "DHCP Reservation Validation Report generated successfully: $reportFilePath"
