<#
.SYNOPSIS
    SCRIPT 02: INSTALADOR DINÂMICO VIA GITHUB
    O Token é puxado automaticamente do Custom Field do Cliente no Atera.
#>

param (
    [string]$CustomerToken = ""
)

# --- 1. VALIDAÇÃO DO TOKEN ---
if ([string]::IsNullOrWhiteSpace($CustomerToken) -or $CustomerToken -eq "{{AcronisToken}}") {
    Write-Host "[ERRO] Token não identificado. Verifique o Custom Field no Atera." -ForegroundColor Red
    exit
}

# --- 2. CONFIGURAÇÃO DE AMBIENTE ---
$BaseUrl  = "https://github.com/beatrizmelo-web/Instalador_Mestre_Acronis/releases/download/v1.0"
$urlCloud = "https://br02-cloud.acronis.com"
$dir      = "C:\Windows\Temp\AcronisInstaller"
$exe      = "C:\Program Files\BackupClient\RegisterAgentTool\register_agent.exe"

Write-Host "[I] Iniciando instalação para o Token: $CustomerToken" -ForegroundColor Cyan

# --- 3. LISTA DE ARQUIVOS PARA DOWNLOAD ---
$FilesToDownload = @(
    "BackupClient64.msi", "BackupClient64.msi.mst", 
    "bc647.cab", "bc648.cab", "bc649.cab", "bc6410.cab", "bc6411.cab", "bc6412.cab", "bc6413.cab", "bc6414.cab", "bc6415.cab",
    "bc6420.cab", "bc6421.cab", "bc6423.cab", "bc6424.cab", "bc6425.cab", "bc6426.cab", "bc6427.cab", "bc6428.cab", "bc6429.cab",
    "bc6430.cab", "bc6431.cab", "bc6432.cab", "bc6433.cab", "bc6434.cab", "bc6435.cab",
    "bc6440.cab", "bc6441.cab", "bc6442.cab", "bc6444.cab", "bc6445.cab", "bc6446.cab", "bc6449.cab",
    "bc6450.cab", "bc6454.cab", "bc6455.cab"
)

# --- 4. PROCESSO DE DOWNLOAD ---
if (!(Test-Path $dir)) { 
    New-Item -ItemType Directory -Path $dir | Out-Null 
}

Write-Host "--- Verificando arquivos no GitHub ---" -ForegroundColor Cyan
foreach ($file in $FilesToDownload) {
    $target = Join-Path $dir $file
    if (!(Test-Path $target)) {
        Write-Host "Baixando: $file..." -ForegroundColor Gray
        try {
            Invoke-WebRequest -Uri "$BaseUrl/$file" -OutFile $target -MaximumRedirection 5 -ErrorAction Stop
        } catch {
            Write-Host "[ERRO CRÍTICO] Falha ao baixar $file. Verifique a conexão." -ForegroundColor Red
            exit
        }
    }
}

# --- 5. INSTALAÇÃO SILENCIOSA ---
Write-Host "--- Iniciando Instalação MSI ---" -ForegroundColor Cyan
$msiFile = "$dir\BackupClient64.msi"
$mstFile = "$dir\BackupClient64.msi.mst"

$p = Start-Process "msiexec.exe" -ArgumentList "/i `"$msiFile`" TRANSFORMS=`"$mstFile`" /qn /norestart" -Wait -PassThru

# --- 6. REGISTRO NO PAINEL ---
if ($p.ExitCode -in 0, 3010) {
    Write-Host "Instalação concluída. Aguardando serviços (20s)..." -ForegroundColor Gray
    Start-Sleep -Seconds 20
    
    if (Test-Path $exe) {
        # USA O TOKEN QUE VEIO DO PARÂMETRO
        $res = & $exe -o register -t cloud -a $urlCloud --token $CustomerToken
        Write-Host "RESULTADO DO REGISTRO: $res" -ForegroundColor Green
    } else {
        Write-Host "[ERRO] Ferramenta de registro não encontrada em: $exe" -ForegroundColor Red
    }
} else {
    Write-Host "[ERRO] O instalador MSI retornou erro: $($p.ExitCode)" -ForegroundColor Red
    Write-Host "Dica: Tente rodar o script 01 de LIMPEZA novamente." -ForegroundColor Yellow
}
