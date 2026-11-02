# Build a single .tex file with pdflatex and move the PDF to an output directory.
# Intermediate files go to a temp directory, deleted on success and kept on failure so the log can be read.
# Usage: .\build_file.ps1 <file>[.tex] <output-dir>
$ErrorActionPreference = 'Stop'

if ($args.Count -ne 2) {
    Write-Host 'usage: build_file.ps1 <file>[.tex] <output-dir>' -ForegroundColor Red
    exit 1
}

# Resolve both paths now, relative to the caller's directory, since the build runs from the file's directory
$PathResolver = $ExecutionContext.SessionState.Path
$TexFile = $PathResolver.GetUnresolvedProviderPathFromPSPath(($args[0] -replace '\.tex$', '') + '.tex')
$OutputDir = $PathResolver.GetUnresolvedProviderPathFromPSPath($args[1])

if (-not (Get-Command pdflatex -ErrorAction SilentlyContinue)) {
    Write-Host 'error: pdflatex not found in PATH' -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $TexFile -PathType Leaf)) {
    Write-Host "error: $TexFile not found" -ForegroundColor Red
    exit 1
}

$Main = [System.IO.Path]::GetFileNameWithoutExtension($TexFile)
$TexDir = Split-Path -Parent $TexFile
$BuildDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$LogFile = Join-Path $BuildDir "$Main.log"

# Two passes so cross-references resolve. Run from the file's directory so its relative \input paths work.
Push-Location -LiteralPath $TexDir
foreach ($pass in 1..2) {
    Write-Host "==> pdflatex pass $pass"
    pdflatex -interaction=nonstopmode -halt-on-error -file-line-error `
        "-output-directory=$BuildDir" "$Main.tex" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Host "error: pdflatex failed, see $LogFile" -ForegroundColor Red
        if (Test-Path -LiteralPath $LogFile) {
            Select-String -LiteralPath $LogFile -Pattern '^.+:\d+:|^!' |
                Select-Object -First 20 |
                ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        }
        exit 1
    }
}
Pop-Location

$BuiltPdf = Join-Path $BuildDir "$Main.pdf"
if (-not (Test-Path -LiteralPath $BuiltPdf)) {
    Write-Host "error: expected PDF was not generated at $BuiltPdf" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$PdfFile = Join-Path $OutputDir "$Main.pdf"
Move-Item -Force -LiteralPath $BuiltPdf -Destination $PdfFile
Remove-Item -Recurse -Force -LiteralPath $BuildDir
Write-Host "==> built $PdfFile"
