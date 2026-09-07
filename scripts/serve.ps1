# Minimal static file server for previewing the al-folio prototype.
# Uses TcpListener (no admin / URL-ACL needed, unlike HttpListener).
param(
    [int]$Port = 8123,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Continue"

$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".webp" = "image/webp"
    ".pdf"  = "application/pdf"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"  = "font/ttf"
    ".txt"  = "text/plain; charset=utf-8"
    ".xml"  = "application/xml; charset=utf-8"
}

$rootFull = (Resolve-Path $Root).Path
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Output "READY: serving $rootFull at http://127.0.0.1:$Port/"

function Send-Response {
    param($Stream, [int]$Status, [string]$Reason, [string]$ContentType, [byte[]]$Body)
    $head = "HTTP/1.1 $Status $Reason`r`n" +
            "Content-Type: $ContentType`r`n" +
            "Content-Length: $($Body.Length)`r`n" +
            "Cache-Control: no-store`r`n" +
            "Connection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    $Stream.Write($headBytes, 0, $headBytes.Length)
    if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $stream.ReadTimeout = 5000

        # Read request head (byte at a time until CRLFCRLF -- head is small)
        $sb = New-Object System.Text.StringBuilder
        $buf = New-Object byte[] 1
        while ($true) {
            $n = $stream.Read($buf, 0, 1)
            if ($n -le 0) { break }
            [void]$sb.Append([char]$buf[0])
            if ($sb.Length -ge 4) {
                $tail = $sb.ToString($sb.Length - 4, 4)
                if ($tail -eq "`r`n`r`n") { break }
            }
            if ($sb.Length -gt 16384) { break }
        }

        $head = $sb.ToString()
        $firstLine = ($head -split "`r`n")[0]
        $parts = $firstLine -split " "
        if ($parts.Count -lt 2) { $client.Close(); continue }

        $urlPath = $parts[1]
        $urlPath = ($urlPath -split "\?")[0]
        $urlPath = [System.Uri]::UnescapeDataString($urlPath)
        if ($urlPath -eq "/") { $urlPath = "/prototype/index.html" }
        $relative = $urlPath.TrimStart("/") -replace "/", "\"

        $candidate = Join-Path $rootFull $relative
        $resolved = $null
        try { $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path } catch { $resolved = $null }

        # Directory -> index.html
        if ($resolved -and (Test-Path -LiteralPath $resolved -PathType Container)) {
            $idx = Join-Path $resolved "index.html"
            if (Test-Path -LiteralPath $idx) { $resolved = (Resolve-Path -LiteralPath $idx).Path } else { $resolved = $null }
        }

        # Contain to root (no path traversal)
        if ($resolved -and -not $resolved.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $resolved = $null
        }

        if ($resolved -and (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($resolved).ToLower()
            $ct = $mime[$ext]
            if (-not $ct) { $ct = "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($resolved)
            Send-Response -Stream $stream -Status 200 -Reason "OK" -ContentType $ct -Body $bytes
            Write-Output "200 $urlPath ($($bytes.Length) bytes)"
        }
        else {
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $urlPath")
            Send-Response -Stream $stream -Status 404 -Reason "Not Found" -ContentType "text/plain; charset=utf-8" -Body $msg
            Write-Output "404 $urlPath"
        }
    }
    catch {
        Write-Output "ERR $($_.Exception.Message)"
    }
    finally {
        if ($client) { try { $client.Close() } catch {} }
    }
}
