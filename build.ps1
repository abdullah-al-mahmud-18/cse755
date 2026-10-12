# Build main.tex with pdflatex. Intermediate files go to build/, the PDF to the project root.
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$Main = 'main'
$Output = 'cse755'
$BuildDir = Join-Path $Root 'build'

Set-Location $Root

if (-not (Get-Command pdflatex -ErrorAction SilentlyContinue)) {
    Write-Error 'pdflatex not found in PATH'
    exit 1
}

# build/lectures is needed if lectures are ever pulled in with \include (it writes per-file .aux)
New-Item -ItemType Directory -Force -Path (Join-Path $BuildDir 'lectures') | Out-Null

$LogFile = Join-Path $BuildDir "$Main.log"

# Two passes so the table of contents and cross-references resolve
foreach ($pass in 1..2) {
    Write-Host "==> pdflatex pass $pass"
    pdflatex -interaction=nonstopmode -halt-on-error -file-line-error `
        "-output-directory=$BuildDir" "$Main.tex" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "error: pdflatex failed, see $LogFile" -ForegroundColor Red
        if (Test-Path $LogFile) {
            Select-String -Path $LogFile -Pattern '^.+:\d+:|^!' |
                Select-Object -First 20 |
                ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        }
        exit 1
    }
}

Move-Item -Force (Join-Path $BuildDir "$Main.pdf") (Join-Path $Root "$Output.pdf")
Write-Host "==> built $(Join-Path $Root "$Output.pdf")"
