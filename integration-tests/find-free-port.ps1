param(
    [int]$Start = 18080
)

for ($p = $Start; $p -lt $Start + 100; $p++) {
    $inUse = $true
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect("127.0.0.1", $p)
        $client.Close()
    } catch {
        $inUse = $false
    }
    if (-not $inUse) {
        Write-Output $p
        exit 0
    }
}

Write-Error "no free port found in range $Start-$($Start + 99)"
exit 1
