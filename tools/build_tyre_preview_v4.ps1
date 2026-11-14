$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    flutter build apk --debug -t lib/preview/tyre_preview_main.dart --android-project-arg=carPreview=true --build-name=1.0.0-tyre.4 --build-number=4
    if ($LASTEXITCODE -ne 0) { throw 'Tyre preview build failed.' }
    $previewMetadata = Get-Content -LiteralPath 'build/app/outputs/apk/debug/output-metadata.json' -Raw | ConvertFrom-Json
    if ($previewMetadata.applicationId -ne 'com.socialstories.social_stories.carpreview') { throw 'Preview package is not isolated.' }
    New-Item -ItemType Directory -Force dist | Out-Null
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-debug.apk' -Destination 'dist/fix-my-broken-car-tyre-preview-v4.apk'
} finally { Pop-Location }
