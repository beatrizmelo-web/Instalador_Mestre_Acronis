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

# --- CONFIGURAÇÕES ---
$BaseUrl   = "https://github.com/beatrizmelo-web/Instalador_Mestre_Acronis/releases/download/v1.0"
$UrlCloud  = "https://br02-cloud.acronis.com"
$Dir       = "C:\Windows\Temp\AcronisInstaller"
$MsiFile   = Join-Path $Dir "BackupClient64.msi"
$MstFile   = Join-Path $Dir "BackupClient64.msi.mst"
$RegisterExe = "C:\Program Files\BackupClient\RegisterAgentTool\register_agent.exe"

$FilesToDownload = @(
    "BackupClient64.msi",
    "BackupClient64.msi.mst",
    "bc647.cab", "bc648.cab", "bc649.cab", "bc6410.cab", "bc6411.cab", "bc6412.cab", "bc6413.cab", "bc6414.cab", "bc6415.cab",
    "bc6420.cab", "bc6421.cab", "bc6423.cab", "bc6424.cab", "bc6425.cab", "bc6426.cab", "bc6427.cab", "bc6428.cab", "bc6429.cab",
    "bc6430.cab", "bc6431.cab", "bc6432.cab", "bc6433.cab", "bc6434.cab", "bc6435.cab",
    "bc6440.cab", "bc6441.cab", "bc6442.cab", "bc6444.cab", "bc6445.cab", "bc6446.cab", "bc6449.cab",
    "bc6450.cab", "bc6454.cab", "bc6455.cab"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[I] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERRO] $Message" -ForegroundColor Red
}

try {
    # --- 1. VALIDAÇÃO ---
    if ([string]::IsNullOrWhiteSpace($CustomerToken)) {
        throw "CustomerToken não recebido."
    }

    Write-Info "Iniciando instalação do Acronis"

    # --- 2. PREPARAÇÃO DO DIRETÓRIO ---
    if (-not (Test-Path $Dir)) {
        New-Item -Path $Dir -ItemType Directory -Force | Out-Null
    }

    # --- 3. DOWNLOAD DOS ARQUIVOS ---
    foreach ($File in $FilesToDownload) {
        $Target = Join-Path $Dir $File

        if (-not (Test-Path $Target)) {
            Write-Info "Baixando $File"
            Invoke-WebRequest -Uri "$BaseUrl/$File" -OutFile $Target -MaximumRedirection 5 -UseBasicParsing -ErrorAction Stop
        }
    }

    # --- 4. VALIDAÇÃO DOS ARQUIVOS PRINCIPAIS ---
    if (-not (Test-Path $MsiFile)) {
        throw "Arquivo MSI não encontrado: $MsiFile"
    }

    if (-not (Test-Path $MstFile)) {
        throw "Arquivo MST não encontrado: $MstFile"
    }

    Write-Ok "Arquivos baixados com sucesso"

    # --- 5. INSTALAÇÃO SILENCIOSA ---
    Write-Info "Executando instalação silenciosa"
    $InstallProcess = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList "/i `"$MsiFile`" TRANSFORMS=`"$MstFile`" /qn /norestart" `
        -Wait -PassThru

    if ($InstallProcess.ExitCode -notin 0, 3010) {
        throw "O instalador MSI retornou erro: $($InstallProcess.ExitCode)"
    }

    if ($InstallProcess.ExitCode -eq 3010) {
        Write-Warn "Instalação concluída com solicitação de reinício (3010)"
    } else {
        Write-Ok "Instalação concluída"
    }

    # --- 6. AGUARDA A DISPONIBILIDADE DO REGISTRADOR ---
    Write-Info "Aguardando disponibilização da ferramenta de registro"
    $MaxWaitSeconds = 60
    $Elapsed = 0

    while ((-not (Test-Path $RegisterExe)) -and ($Elapsed -lt $MaxWaitSeconds)) {
        Start-Sleep -Seconds 5
        $Elapsed += 5
    }

    if (-not (Test-Path $RegisterExe)) {
        throw "Ferramenta de registro não encontrada em: $RegisterExe"
    }

    Write-Ok "Ferramenta de registro localizada"

    # --- 7. REGISTRO / AUTENTICAÇÃO ---
    Write-Info "Registrando agente com o token do cliente"

    $RegisterProcess = Start-Process -FilePath $RegisterExe `
        -ArgumentList "-o register -t cloud -a $UrlCloud --token $CustomerToken" `
        -Wait -PassThru -NoNewWindow

    if ($RegisterProcess.ExitCode -ne 0) {
        throw "Falha ao registrar o agente. ExitCode: $($RegisterProcess.ExitCode)"
    }

    Write-Ok "Registro concluído com sucesso"

    # --- 8. VALIDAÇÃO FINAL ---
    Write-Info "Validando se o agente está em execução"
    Start-Sleep -Seconds 10

    $ServicesToCheck = @("MMS", "BackupGateway", "ManagedMachineService")
    $RunningService = $null

    foreach ($ServiceName in $ServicesToCheck) {
        $Svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Svc -and $Svc.Status -eq "Running") {
            $RunningService = $Svc
            break
        }
    }

    if ($RunningService) {
        Write-Ok "Acronis instalado, autenticado e em execução. Serviço detectado: $($RunningService.Name)"
        exit 0
    }

    Write-Warn "Instalado e autenticado, mas não foi possível confirmar um serviço em execução"
    exit 0
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
