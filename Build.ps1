param (
    [string]$Version = "luajit",
    [string]$BuildFromSource = "false"
)

$Build = [System.Convert]::ToBoolean($BuildFromSource)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$BuildDir = "build"

function Build-FromSource($feature) {
    if (-not (Test-Path $BuildDir)) {
        New-Item -ItemType Directory -Path $BuildDir | Out-Null
    }

    cargo build --release --features=$feature

    $targetTokenizerFile = "avante_tokenizers.dll"
    $targetTemplatesFile = "avante_templates.dll"
    Copy-Item (Join-Path "target\release\avante_tokenizers.dll") (Join-Path $BuildDir $targetTokenizerFile)
    Copy-Item (Join-Path "target\release\avante_templates.dll") (Join-Path $BuildDir $targetTemplatesFile)

    Remove-Item -Recurse -Force "target"
}


function Download-Prebuilt($feature) {
    Write-Host "Downloading prebuilt binaries for $feature..."

    $REPO_OWNER = "yetone"
    $REPO_NAME = "avante.nvim"
    $SCRIPT_DIR = $PSScriptRoot
    $TARGET_DIR = Join-Path $SCRIPT_DIR "build"
    $PLATFORM = "windows"
 $LUA_VERSION = if ($feature) { $feature } else { "luajit" }
    $ARTIFACT_NAME_PATTERN = "avante_lib-$PLATFORM-latest-$LUA_VERSION"

    $LATEST_RELEASE = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    $ARTIFACT_URL = $LATEST_RELEASE.assets | Where-Object { $_.name -like "*$ARTIFACT_NAME_PATTERN*" } | Select-Object -ExpandProperty browser_download_url

    if (-not $ARTIFACT_URL) {
        Write-Host "Error: No matching asset found for $ARTIFACT_NAME_PATTERN." -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $TARGET_DIR)) {
        New-Item -ItemType Directory -Path $TARGET_DIR | Out-Null
    }

    try {
        # Create a temporary file
        $TempFile = [System.IO.Path]::GetTempFileName()
        $TempFileZip = "$TempFile.zip"
        Rename-Item -Path $TempFile -NewName $TempFileZip

        # Download the artifact
        Invoke-WebRequest -Uri $ARTIFACT_URL -OutFile $TempFileZip
        Expand-Archive -Path $TempFileZip -DestinationPath $TARGET_DIR -Force
        Remove-Item $TempFileZip
    } catch {
        Write-Host "Error during download or extraction: $_" -ForegroundColor Red
        exit 1
    }
}

function Main {
    Set-Location $PSScriptRoot
    if ($Build) {
        Write-Host "Building for $Version..."
        Build-FromSource $Version
    } else {
        Write-Host "Downloading for $Version..."
        Download-Prebuilt $Version
    }
    Write-Host "Completed!"
}

# Run the main function
Main
