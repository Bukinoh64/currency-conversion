$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$htmlPath = Join-Path $projectRoot "index.html"
$stylesPath = Join-Path $projectRoot "css\styles.css"
$appPath = Join-Path $projectRoot "js\app.js"
$currenciesPath = Join-Path $projectRoot "js\currencies.js"
$outputPath = Join-Path $projectRoot "mobile.html"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$styles = [System.IO.File]::ReadAllText($stylesPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$currencies = [System.IO.File]::ReadAllText($currenciesPath, [System.Text.Encoding]::UTF8)

$moduleImport = 'import { currencies } from "./currencies.js";'
if (-not $app.Contains($moduleImport)) {
  throw "Could not find the currency data import in js\app.js."
}
$app = $app.Replace($moduleImport, "")
$currencies = $currencies.Replace("export const ", "const ")

if (-not $app.Contains('if ("serviceWorker" in navigator) {')) {
  throw "Could not find the service-worker registration in js\app.js."
}
$app = $app.Substring(0, $app.IndexOf('if ("serviceWorker" in navigator) {')).TrimEnd()

foreach ($entry in @(
  @{ Pattern = '(?s)<link\s+rel="stylesheet"\s+href="\./css/styles\.css"\s*/?>'; Replacement = "<style>`n$styles`n  </style>" },
  @{ Pattern = '(?s)<script\s+type="module"\s+src="\./js/app\.js"\s*></script>'; Replacement = "<script>`n$currencies`n$app`n  </script>" },
  @{ Pattern = '(?m)^\s*<link\s+rel="manifest"\s+href="\./manifest\.webmanifest"\s*/?>\r?\n'; Replacement = "" },
  @{ Pattern = '(?m)^\s*<link\s+rel="icon"\s+href="\./assets/icon\.svg"\s+type="image/svg\+xml"\s*/?>\r?\n'; Replacement = "" },
  @{ Pattern = '(?m)^\s*<link\s+rel="apple-touch-icon"\s+href="\./assets/icon-192\.png"\s*/?>\r?\n'; Replacement = "" }
)) {
  if ($html -notmatch $entry.Pattern) {
    throw "Could not find a required app shell reference: $($entry.Pattern)"
  }
  $replacement = $entry.Replacement
  $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
    param($match)
    return $replacement
  }
  $html = [System.Text.RegularExpressions.Regex]::Replace(
    $html,
    $entry.Pattern,
    $evaluator,
    1
  )
}

[System.IO.File]::WriteAllText(
  $outputPath,
  $html,
  [System.Text.UTF8Encoding]::new($false)
)
Write-Host "Created $outputPath"
