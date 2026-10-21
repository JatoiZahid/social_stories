# Switches the Android release build from the debug key to android/key.properties.
# Works with both build.gradle.kts (Flutter 3.29+) and build.gradle (older).
# Idempotent: skips files that are already patched.
param([Parameter(Mandatory = $true)][string]$AppDir)

$marker = 'social_stories: release signing'
$kts = Join-Path $AppDir 'build.gradle.kts'
$groovy = Join-Path $AppDir 'build.gradle'

function Save([string]$path, [string]$text) {
    $full = (Resolve-Path $path).Path
    [System.IO.File]::WriteAllText($full, $text, (New-Object System.Text.UTF8Encoding($false)))
}

if (Test-Path $kts) {
    $src = Get-Content -Raw -Path $kts
    if ($src.Contains($marker)) { Write-Host '      Already configured.'; exit 0 }

    $imports = "import java.io.FileInputStream`r`nimport java.util.Properties`r`n`r`n"
    $loader = @"

// $marker
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
"@
    $signing = @"
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
"@
    $plugins = [regex]::Match($src, 'plugins\s*\{[^}]*\}')
    if (-not $plugins.Success) { Write-Error 'Could not find the plugins { } block.'; exit 1 }
    $src = $src.Insert($plugins.Index + $plugins.Length, $loader)
    $src = $imports + $src

    $bt = [regex]::new('(?m)^\s*buildTypes\s*\{')
    if (-not $bt.IsMatch($src)) { Write-Error 'Could not find buildTypes { }.'; exit 1 }
    $src = $bt.Replace($src, $signing, 1)
    $src = $src -replace 'signingConfigs\.getByName\("debug"\)', 'signingConfigs.getByName("release")'

    Save $kts $src
    Write-Host '      Patched build.gradle.kts'
    exit 0
}

if (Test-Path $groovy) {
    $src = Get-Content -Raw -Path $groovy
    if ($src.Contains($marker)) { Write-Host '      Already configured.'; exit 0 }

    $loader = @"
// $marker
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"@
    $signing = @"
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
"@
    $android = [regex]::new('(?m)^android\s*\{')
    if (-not $android.IsMatch($src)) { Write-Error 'Could not find android { }.'; exit 1 }
    $src = $android.Replace($src, ($loader + 'android {'), 1)

    $bt = [regex]::new('(?m)^\s*buildTypes\s*\{')
    $src = $bt.Replace($src, $signing, 1)
    $src = $src -replace 'signingConfig\s*=?\s*signingConfigs\.debug', 'signingConfig = signingConfigs.release'

    Save $groovy $src
    Write-Host '      Patched build.gradle'
    exit 0
}

Write-Error "No build.gradle(.kts) found in $AppDir. Run setup.bat first."
exit 1
