# Build the isolated Android preview alongside the existing app.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    flutter build apk --debug -t lib/preview/car_preview_main.dart --android-project-arg=carPreview=true --build-name=1.0.0-preview.2 --build-number=2
    if ($LASTEXITCODE -ne 0) { throw 'Preview build failed.' }
    $previewMetadata = Get-Content -LiteralPath 'build/app/outputs/apk/debug/output-metadata.json' -Raw | ConvertFrom-Json
    if ($previewMetadata.applicationId -ne 'com.socialstories.social_stories.carpreview') {
        throw 'Expected isolated preview package was not generated.'
    }
    New-Item -ItemType Directory -Force dist | Out-Null
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-debug.apk' -Destination 'dist/fix-my-broken-car-preview-v2.apk'
} finally {
    Pop-Location
}
