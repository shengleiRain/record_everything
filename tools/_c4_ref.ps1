$f = 'lib\features\settings\pages\settings_page.dart'
$c = Get-Content $f -Raw -Encoding UTF8

# 1. Add import for settings_providers if missing
if ($c -notmatch "import '\.\./providers/settings_providers\.dart'") {
    $c = $c -replace "(import '\.\./\.\./\.\./core/utils/toast\.dart';)", "`$1`nimport '../providers/settings_providers.dart';"
}

# 2. Insert _AppearanceGroup() reference before the data-import group
$marker = "          const SizedBox(height: 12),`r`n          _SettingsGroup(`r`n            rows: [`r`n              _SettingsRowData(`r`n                icon: '入',"
$replacement = "          const SizedBox(height: 12),`r`n          _AppearanceGroup(),`r`n          const SizedBox(height: 12),`r`n          _SettingsGroup(`r`n            rows: [`r`n              _SettingsRowData(`r`n                icon: '入',"

# Try CRLF first, then LF
if ($c.Contains($marker)) {
    $c = $c.Replace($marker, $replacement)
    Write-Output 'inserted reference (CRLF marker)'
} else {
    $markerLF = $marker -replace "`r`n", "`n"
    $replacementLF = $replacement -replace "`r`n", "`n"
    if ($c.Contains($markerLF)) {
        $c = $c.Replace($markerLF, $replacementLF)
        Write-Output 'inserted reference (LF marker)'
    } else {
        Write-Output 'MARKER NOT FOUND - aborting'
        exit 1
    }
}

Set-Content -Path $f -Value $c -NoNewline -Encoding UTF8
Write-Output 'reference inserted'
