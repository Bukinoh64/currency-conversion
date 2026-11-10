param(
  [Parameter(Mandatory = $true)]
  [string]$AppRoot
)

$ErrorActionPreference = "Stop"
$root = [System.IO.Path]::GetFullPath($AppRoot)
if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
  $root += [System.IO.Path]::DirectorySeparatorChar
}

$port = 4173
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)

try {
  $listener.Start()
} catch {
  Write-Host "Could not start the app. Port $port may already be in use."
  Write-Host $_.Exception.Message
  exit 1
}

$url = "http://127.0.0.1:$port/"
Write-Host "Currency converter is running at $url"
Write-Host "Keep this window open while using the app. Close it to stop."
Start-Process $url

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".js" = "text/javascript; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
  ".svg" = "image/svg+xml"
  ".png" = "image/png"
  ".ico" = "image/x-icon"
}

try {
  while ($listener.Server.IsBound) {
    $client = $null

    try {
      $client = $listener.AcceptTcpClient()
      $client.ReceiveTimeout = 5000
      $client.SendTimeout = 5000
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new(
        $stream,
        [System.Text.Encoding]::ASCII,
        $false,
        1024,
        $true
      )

      $requestLine = $reader.ReadLine()
      if (-not $requestLine) {
        continue
      }

      $request = $requestLine -split " ", 3
      $method = $request[0]
      $requestPath = $request[1].Split("?")[0]
      $reader.ReadLine() | Out-Null
      while ($true) {
        $header = $reader.ReadLine()
        if ([string]::IsNullOrEmpty($header)) {
          break
        }
      }

      $statusCode = 200
      $statusText = "OK"
      $body = [byte[]]@()
      $contentType = "text/plain; charset=utf-8"

      if ($method -ne "GET" -and $method -ne "HEAD") {
        $statusCode = 405
        $statusText = "Method Not Allowed"
        $body = [System.Text.Encoding]::UTF8.GetBytes("Method not allowed")
      } else {
        $relativePath = [System.Uri]::UnescapeDataString($requestPath.TrimStart("/"))
        if ([string]::IsNullOrEmpty($relativePath)) {
          $relativePath = "index.html"
        }

        $filePath = [System.IO.Path]::GetFullPath(
          [System.IO.Path]::Combine($root, $relativePath)
        )

        if (-not $filePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
          $statusCode = 403
          $statusText = "Forbidden"
          $body = [System.Text.Encoding]::UTF8.GetBytes("Forbidden")
        } elseif (-not [System.IO.File]::Exists($filePath)) {
          $statusCode = 404
          $statusText = "Not Found"
          $body = [System.Text.Encoding]::UTF8.GetBytes("Not found")
        } else {
          $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
          if ($mimeTypes.ContainsKey($extension)) {
            $contentType = $mimeTypes[$extension]
          }
          $body = [System.IO.File]::ReadAllBytes($filePath)
        }
      }

      $responseHeaders = @(
        "HTTP/1.1 $statusCode $statusText"
        "Content-Type: $contentType"
        "Content-Length: $($body.Length)"
        "Cache-Control: no-cache"
        "X-Content-Type-Options: nosniff"
        "Connection: close"
        ""
        ""
      ) -join "`r`n"

      $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($responseHeaders)
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      if ($method -ne "HEAD" -and $body.Length -gt 0) {
        $stream.Write($body, 0, $body.Length)
      }
      $stream.Flush()
    } catch {
      Write-Host "Request failed: $($_.Exception.Message)"
    } finally {
      if ($null -ne $client) {
        $client.Dispose()
      }
    }
  }
} finally {
  $listener.Stop()
}
