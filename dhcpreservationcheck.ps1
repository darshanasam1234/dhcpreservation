
$dhcpServer = Read-Host "Please enter the DHCP Server Name"
$scopeId = Read-Host "Please enter the DHCP Scope ID"
$dnsServer = Read-Host "Please enter the DNS Server Name"


function Test-DnsResolution {
    param (
        [string]$ip,
        [string]$dnsServer
    )
    try {
        $resolvedName = [System.Net.Dns]::GetHostEntry($ip, $dnsServer).HostName
        return $true
    } catch {
        return $false
    }
}

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
    <h2>DHCP Reservation Validation Report</h2>
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


$reportFilePath = "$env:USERPROFILE\Desktop\DHCP_Reservation_Report_$scopeId.html"
$htmlReport | Out-File -FilePath $reportFilePath -Encoding UTF8


Start-Process $reportFilePath

Write-Host "DHCP Reservation Validation Report generated successfully: $reportFilePath"
