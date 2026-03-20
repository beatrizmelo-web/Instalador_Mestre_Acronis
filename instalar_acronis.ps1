<#
.SYNOPSIS
    SCRIPT 02 - INSTALADOR ACRONIS VIA GITHUB
    Recebe o CustomerToken do script leve do Atera, baixa os arquivos,
    instala o agente e registra no tenant correto.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$CustomerToken
)

$BaseUrl  = "https://github.com/beatrizmelo-web/Instalador_Mestre_Acronis/releases/download/v1.0"
$UrlCloud = "https://br02-cloud.acronis.com"
$Dir      = "C:\Windows\Temp\AcronisInstaller"
$MsiFile  = Join-Path $Dir "BackupClient64.msi"
$MstFile  = Join-Path $Dir "BackupClient64.msi.mst"
$RegExe   = "C:\Program Files\BackupClient\RegisterAgentTool\register_agent.exe"

$FilesToDownload = @(
    "BackupClient64.msi", "BackupClient64.msi.mst",
    "bc647.cab", "bc648.cab", "bc649.cab", "bc6410.cab", "bc6411.cab", "bc6412.cab", "bc6413.cab", "bc6414.cab", "bc6415.cab",
    "bc6420.cab", "bc6421.cab", "bc6423.cab", "bc6424.cab", "bc6425.cab", "bc6426.cab", "bc6427.cab", "bc6428.cab", "bc6429.cab",
    "bc6430.cab", "bc6431.cab", "bc6432.cab", "bc6433.cab", "bc6434.cab", "bc6435.cab",
    "bc6440.cab", "bc6441.cab", "bc6442.cab", "bc6444.cab", "bc6445.cab", "bc6446.cab", "bc6449.cab",
    "bc6450.cab", "bc6454.cab", "bc6455.cab"
)

try {
    if ([string]::IsNullOrWhiteSpace($CustomerToken)) {
        throw "CustomerToken não recebido."
    }

    Write-Host "[I] Iniciando instalação do Acronis..." -ForegroundColor Cyan

    if (-not (Test-Path $Dir)) {
        New-Item -Path $Dir -ItemType Directory -Force | Out-Null
    }

    foreach ($File in $FilesToDownload) {
        $Target = Join-Path $Dir $File
        if (-not (Test-Path $Target)) {
            Write-Host "[I] Baixando $File..." -ForegroundColor Gray
            Invoke-WebRequest -Uri "$BaseUrl/$File" -OutFile $Target -MaximumRedirection 5 -UseBasicParsing -ErrorAction Stop
        }
    }

    if (-not (Test-Path $MsiFile)) {
        throw "MSI não encontrado: $MsiFile"
    }

    if (-not (Test-Path $MstFile)) {
        throw "MST não encontrado: $MstFile"
    }

    Write-Host "[I] Executando instalação silenciosa..." -ForegroundColor Cyan
    $Install = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList "/i `"$MsiFile`" TRANSFORMS=`"$MstFile`" /qn /norestart" `
        -Wait -PassThru

    if ($Install.ExitCode -notin 0,3010) {
        throw "O MSI retornou código $($Install.ExitCode)."
    }

    Write-Host "[I] Instalação concluída. Aguardando serviços..." -ForegroundColor Cyan
    Start-Sleep -Seconds 20

    if (-not (Test-Path $RegExe)) {
        throw "Ferramenta de registro não encontrada em: $RegExe"
    }

    Write-Host "[I] Registrando agente no tenant do cliente..." -ForegroundColor Cyan
    $Register = Start-Process -FilePath $RegExe `
        -ArgumentList "-o register -t cloud -a $UrlCloud --token $CustomerToken" `
        -Wait -PassThru -NoNewWindow

    if ($Register.ExitCode -ne 0) {
        throw "Falha no registro do agente. ExitCode: $($Register.ExitCode)"
    }

    Start-Sleep -Seconds 10

    $BackupService = Get-Service -Name "MMS" -ErrorAction SilentlyContinue
    if ($BackupService -and $BackupService.Status -eq "Running") {
        Write-Host "[SUCESSO] Acronis instalado, registrado e em execução." -ForegroundColor Green
        exit 0
    }

    Write-Host "[AVISO] Registro concluído, mas não consegui confirmar o serviço MMS em execução." -ForegroundColor Yellow
    exit 0
}
catch {
    Write-Host "[ERRO] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
