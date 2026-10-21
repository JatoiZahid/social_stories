# Adds what the app needs to AndroidManifest.xml:
#  - the TTS_SERVICE <queries> entry flutter_tts needs on Android 11+
#  - INTERNET permission and plain-http access, to fetch stories from the story server
# Idempotent: does nothing if they are already there.
param([Parameter(Mandatory = $true)][string]$ManifestPath)

if (-not (Test-Path $ManifestPath)) {
    Write-Error "Manifest not found: $ManifestPath"
    exit 1
}

$xml = Get-Content -Raw -Path $ManifestPath
$original = $xml

if ($xml -notmatch 'android\.intent\.action\.TTS_SERVICE') {
    $intent = @'
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
'@
    if ($xml -match '<queries>') {
        $xml = $xml -replace '<queries>', ("<queries>`r`n" + $intent.TrimEnd())
    } else {
        $block = "    <queries>`r`n" + $intent.TrimEnd() + "`r`n    </queries>`r`n"
        $xml = $xml -replace '</manifest>', ($block + '</manifest>')
    }
    Write-Host '      Added TTS permission.'
}

if ($xml -notmatch 'android\.permission\.INTERNET') {
    $xml = $xml -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
    Write-Host '      Added INTERNET permission.'
}

if ($xml -notmatch 'usesCleartextTraffic') {
    $xml = $xml -replace '<application', '<application android:usesCleartextTraffic="true"'
    Write-Host '      Allowed plain http for the story server.'
}

if ($xml -eq $original) {
    Write-Host '      Already present.'
    exit 0
}

# UTF-8 without BOM so the Android build tools read it cleanly.
$full = (Resolve-Path $ManifestPath).Path
[System.IO.File]::WriteAllText($full, $xml, (New-Object System.Text.UTF8Encoding($false)))
exit 0
