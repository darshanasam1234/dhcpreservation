$dhcpServer = Read-Host "Please enter the DHCP Server Name"

# Function to list the DHCP Scopes
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

List-DhcpScope -DhcpServerName $dhcpServer

$scopeId = Read-Host "Please enter the DHCP Scope ID"
$dnsServer = (Get-DnsClientServerAddress).serveraddresses[0]

# Helper function to convert IP address to a numerical value for sorting
function Convert-IpToNumber {
    param (
        [string]$ip
    )
    $ip.Split('.') | ForEach-Object {[int]$_} | ForEach-Object -Begin {$num = 0} -Process {$num = ($num * 256) + $_} -End {$num}
}

# Function to check forward DNS resolution
function Test-DnsResolution {
    param (
        [string]$ip,
        [string]$dnsServer
    )
    try {
        $result = Resolve-DnsName -Server $dnsServer -Name $ip -ErrorAction SilentlyContinue
        if ($result) {
            return $result.NameHost
        }
    } catch {
        return $false
    }
}

# Function to perform reverse DNS resolution by directly querying the IP
function Test-ReverseDnsResolution {
    param (
        [string]$ip,
        [string]$dnsServer
    )
    try {
        $result = Resolve-DnsName -Server $dnsServer -Name $ip -ErrorAction SilentlyContinue
        if ($result) {
            return $result.NameHost
        }
    } catch {
        return $false
    }
}

# Function to do a ping test
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

# Sort reservations by IP address using numerical conversion
$reservations = $reservations | Sort-Object @{Expression={Convert-IpToNumber $_.IPAddress}}

$tableRows = @()

foreach ($reservation in $reservations) {
    $ipAddress = $reservation.IPAddress
    $clientName = $reservation.Name
    $macAddress = $reservation.ClientId

    $dnsResult = Test-DnsResolution -ip $ipAddress -dnsServer $dnsServer
    $reverseDnsResult = Test-ReverseDnsResolution -ip $ipAddress -dnsServer $dnsServer
    $pingResult = Test-Ping -ip $ipAddress

    # DNS forward lookup status with reservation name comparison
    if ($dnsResult) {
        $dnsForwardStatus = if ($dnsResult -eq $clientName) { 
            "<td style='background-color:green;'>DNS Resolved ($dnsResult)</td>" 
        } else {
            "<td style='background-color:yellow;'>Mismatch ($dnsResult)</td>"
        }
    } else {
        $dnsForwardStatus = "<td style='background-color:red;'>DNS Failed</td>"
    }

    # DNS reverse lookup status with reservation name comparison
    if ($reverseDnsResult) {
        $dnsReverseStatus = if ($reverseDnsResult -eq $clientName) { 
            "<td style='background-color:green;'>Reverse DNS Resolved ($reverseDnsResult)</td>" 
        } else {
            "<td style='background-color:yellow;'>Mismatch ($reverseDnsResult)</td>"
        }
    } else {
        $dnsReverseStatus = "<td style='background-color:red;'>Reverse DNS Failed</td>"
    }

    # Ping status
    $pingStatus = if ($pingResult) { "<td style='background-color:green;'>Ping Success</td>" } else { "<td style='background-color:red;'>Ping Failed</td>" }

    # Overall status
    if ($dnsResult -or $reverseDnsResult -or $pingResult) {
        $overallStatus = "<td style='background-color:green;'>Valid</td>"
    } else {
        $overallStatus = "<td style='background-color:red;'>Invalid</td>"
    }

    # Create table row
    $row = "<tr>
                <td>$clientName</td>
                <td>$ipAddress</td>
                <td>$macAddress</td>
                $dnsForwardStatus
                $dnsReverseStatus
                $pingStatus
                $overallStatus
            </tr>"

    $tableRows += $row
}

# Generate the HTML report
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
    <h2>DHCP Reservation Validation Report (Scope_ID) $($scopeId)</h2>
    <table>
        <tr>
            <th>Client Name</th>
            <th>IP Address</th>
            <th>MAC Address</th>
            <th>DNS Forward Lookup</th>
            <th>DNS Reverse Lookup</th>
            <th>Ping Status</th>
            <th>Overall Status</th>
        </tr>
        $($tableRows -join "`n")
    </table>
</body>
</html>
"@

# Save HTML report to the desktop
$reportFilePath = "$env:USERPROFILE\Desktop\DHCP_Reservation_Report_$scopeId.html"
$htmlReport | Out-File -FilePath $reportFilePath -Encoding UTF8

Start-Process $reportFilePath

Write-Host "DHCP Reservation Validation Report generated successfully: $reportFilePath"
