<#
.SYNOPSIS
    İYTE eduroam Onarım Aracı (Windows 10 / 11)

.DESCRIPTION
    Windows'ta eduroam bağlantı sorunlarını tek tıkla giderir.
    - Bozuk / çift kayıtlı eduroam profillerini (ör. "eduroam 2") temizler
    - Takılı kalmış kayıtlı kullanıcı bilgisini sıfırlar (profil silinince gider)
    - Güncel profili ekler ve bağlanmayı dener
    - İsteğe bağlı "derin temizlik": DNS önbelleği, WLAN servisi, Wi-Fi adaptörü

    Bu betik internetten HİÇBİR ŞEY indirmez, HİÇBİR ŞEYE veri göndermez,
    kullanıcı adı/şifrenizi görmez veya saklamaz. Tüm kod bu dosyada açıktır.

.PARAMETER NoGui
    Arayüz açmadan konsolda çalışır.

.NOTES
    Yazar  : MTYOURMIND
    Lisans : MIT (bkz. LICENSE)
    Resmî bir İYTE aracı DEĞİLDİR. eduroam profil yapılandırması,
    İYTE'nin yayımladığı resmî eduroam profiline dayanır.
#>
[CmdletBinding()]
param(
    [switch]$NoGui
)

$ErrorActionPreference = 'Stop'
$script:ProfileName = 'eduroam'
$script:Sink   = $null    # GUI'de log yazan scriptblock
$script:Busy   = $false

# ---------------------------------------------------------------------------
# eduroam Wi-Fi profili
# NOT: Bu profilde sunucu sertifika doğrulaması kapalıdır
# (PerformServerValidation=false). Bkz. README.md -> "Güvenlik notu".
# ---------------------------------------------------------------------------
$script:ProfileXml = @'
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
	<name>eduroam</name>
	<SSIDConfig>
		<SSID>
			<hex>656475726F616D</hex>
			<name>eduroam</name>
		</SSID>
		<nonBroadcast>false</nonBroadcast>
	</SSIDConfig>
	<connectionType>ESS</connectionType>
	<connectionMode>auto</connectionMode>
	<autoSwitch>false</autoSwitch>
	<MSM>
		<security>
			<authEncryption>
				<authentication>WPA2</authentication>
				<encryption>AES</encryption>
				<useOneX>true</useOneX>
				<FIPSMode xmlns="http://www.microsoft.com/networking/WLAN/profile/v2">false</FIPSMode>
			</authEncryption>
			<PMKCacheMode>disabled</PMKCacheMode>
			<OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
				<cacheUserData>true</cacheUserData>
				<authMode>user</authMode>
				<EAPConfig><EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><EapMethod><Type xmlns="http://www.microsoft.com/provisioning/EapCommon">25</Type><VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId><VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType><AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId></EapMethod><Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig"><Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1"><Type>25</Type><EapType xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV1"><ServerValidation><DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation><ServerNames></ServerNames></ServerValidation><FastReconnect>true</FastReconnect><InnerEapOptional>false</InnerEapOptional><Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1"><Type>26</Type><EapType xmlns="http://www.microsoft.com/provisioning/MsChapV2ConnectionPropertiesV1"><UseWinLogonCredentials>false</UseWinLogonCredentials></EapType></Eap><EnableQuarantineChecks>false</EnableQuarantineChecks><RequireCryptoBinding>false</RequireCryptoBinding><PeapExtensions><PerformServerValidation xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV2">false</PerformServerValidation><AcceptServerName xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV2">false</AcceptServerName><PeapExtensionsV2 xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV2"><AllowPromptingWhenServerCANotFound xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV3">true</AllowPromptingWhenServerCANotFound></PeapExtensionsV2></PeapExtensions></EapType></Eap></Config></EapHostConfig></EAPConfig>
			</OneX>
		</security>
	</MSM>
</WLANProfile>
'@

# ---------------------------------------------------------------------------
# Yönetici yetkisi (UAC onayı ile kendini yeniden başlatır)
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    if ($NoGui) { $argList += '-NoGui' }
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    }
    catch {
        Write-Host 'Yönetici izni verilmedi. Profil işlemleri için yönetici yetkisi gerekir.'
        Read-Host 'Çıkmak için Enter'
    }
    exit
}

# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------
function Write-Log {
    param([string]$Message)
    if ($script:Sink) { & $script:Sink $Message } else { Write-Host $Message }
}

function Wait-Briefly {
    param([double]$Seconds)
    $ticks = [int]($Seconds * 5)
    for ($i = 0; $i -lt $ticks; $i++) {
        Start-Sleep -Milliseconds 200
        if ($script:Sink) { [System.Windows.Forms.Application]::DoEvents() }
    }
}

function Invoke-Netsh {
    param([string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = (& netsh.exe @Arguments 2>&1 | Out-String).Trim()
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
    }
    finally { $ErrorActionPreference = $prev }
}

function Get-WifiAdapters {
    try {
        return @(Get-NetAdapter -Physical -ErrorAction Stop |
                 Where-Object { $_.PhysicalMediaType -match '802\.11' })
    }
    catch { return @() }
}

function Initialize-WlanService {
    $svc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log '[!] WLAN AutoConfig hizmeti yok. Bu cihazda Wi-Fi donanımı/sürücüsü yok gibi görünüyor.'
        return $false
    }
    if ($svc.StartType -eq 'Disabled') {
        Set-Service -Name 'WlanSvc' -StartupType Automatic
        Write-Log '    WLAN AutoConfig hizmeti devre dışıydı, etkinleştirildi.'
    }
    if ($svc.Status -ne 'Running') {
        Start-Service -Name 'WlanSvc'
        Wait-Briefly 2
        Write-Log '    WLAN AutoConfig hizmeti başlatıldı.'
    }
    return $true
}

function Remove-EduroamProfiles {
    $res = Invoke-Netsh @('wlan', 'show', 'profiles')
    $names = @()
    foreach ($line in ($res.Output -split "`r?`n")) {
        if ($line -match ':\s*(eduroam.*?)\s*$') { $names += $Matches[1] }
    }
    $names = @($names | Sort-Object -Unique)
    if ($names.Count -eq 0) {
        Write-Log '    Silinecek eski eduroam profili yok.'
        return
    }
    foreach ($n in $names) {
        $r = Invoke-Netsh @('wlan', 'delete', 'profile', "name=$n")
        if ($r.ExitCode -eq 0) { Write-Log "    Silindi: $n" }
        else { Write-Log "    [!] Silinemedi: $n  ($($r.Output))" }
    }
}

function Add-EduroamProfile {
    # C:\Windows\Temp: yol boşluk içermez, netsh argüman sorunu çıkmaz.
    $tmp = Join-Path $env:SystemRoot ('Temp\eduroam-' + [guid]::NewGuid().ToString('N') + '.xml')
    try {
        [IO.File]::WriteAllText($tmp, $script:ProfileXml, (New-Object Text.UTF8Encoding($false)))
        return (Invoke-Netsh @('wlan', 'add', 'profile', "filename=$tmp", 'user=all'))
    }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Test-EduroamConnected {
    $r = Invoke-Netsh @('wlan', 'show', 'interfaces')
    return [bool]($r.Output -match '(?im)^\s*SSID\s*:\s*eduroam\s*$')
}

function Invoke-DeepClean {
    Write-Log '    DNS önbelleği temizleniyor...'
    & ipconfig.exe /flushdns | Out-Null

    Write-Log '    WLAN AutoConfig hizmeti yeniden başlatılıyor...'
    Restart-Service -Name 'WlanSvc' -Force
    Wait-Briefly 2

    foreach ($a in (Get-WifiAdapters)) {
        Write-Log "    Wi-Fi adaptörü yeniden başlatılıyor: $($a.Name)"
        try { Restart-NetAdapter -Name $a.Name -Confirm:$false }
        catch { Write-Log "    [!] Adaptör yeniden başlatılamadı: $($_.Exception.Message)" }
    }
    Wait-Briefly 4
}

# ---------------------------------------------------------------------------
# Ana akış
# ---------------------------------------------------------------------------
function Invoke-EduroamFix {
    param([bool]$Deep)

    try {
        Write-Log '1/5  Wi-Fi donanımı ve hizmeti kontrol ediliyor...'
        if (-not (Initialize-WlanService)) { return $false }

        $adapters = @(Get-WifiAdapters)
        if ($adapters.Count -eq 0) {
            Write-Log '[!] Wi-Fi adaptörü bulunamadı. Uçak modunu, Wi-Fi düğmesini ve sürücüyü kontrol edin.'
            return $false
        }
        foreach ($a in $adapters) {
            Write-Log "    Adaptör: $($a.InterfaceDescription) [$($a.Status)]"
            if ($a.Status -eq 'Disabled') {
                Enable-NetAdapter -Name $a.Name -Confirm:$false
                Write-Log '    Adaptör devre dışıydı, etkinleştirildi.'
                Wait-Briefly 3
            }
        }

        if ($Deep) {
            Write-Log '2/5  Derin temizlik yapılıyor...'
            Invoke-DeepClean
        }
        else {
            Write-Log '2/5  Derin temizlik atlandı (isteğe bağlı).'
        }

        Write-Log '3/5  Eski eduroam profilleri ve kayıtlı bilgiler siliniyor...'
        Remove-EduroamProfiles

        Write-Log '4/5  Güncel eduroam profili ekleniyor...'
        $add = Add-EduroamProfile
        if ($add.ExitCode -ne 0) {
            Write-Log "[!] Profil eklenemedi: $($add.Output)"
            return $false
        }
        Write-Log '    Profil eklendi.'

        Write-Log '5/5  eduroam''a bağlanılıyor...'
        $conn = Invoke-Netsh @('wlan', 'connect', 'name=eduroam', 'ssid=eduroam')
        if ($conn.ExitCode -ne 0) {
            Write-Log '    eduroam şu an menzilde olmayabilir (kampüs dışı?). Profil yüklendi;'
            Write-Log '    kampüste Wi-Fi listesinden eduroam''a tıklayıp bağlanabilirsiniz.'
            return $true
        }

        for ($i = 0; $i -lt 6; $i++) {
            Wait-Briefly 2
            if (Test-EduroamConnected) {
                Write-Log ''
                Write-Log '✔ eduroam''a bağlandınız.'
                return $true
            }
        }

        Write-Log ''
        Write-Log '✔ Profil hazır. Şimdi son adım sizde:'
        Write-Log '   • Ekranın sağ altında "ek bilgi gerekli" bildirimi veya giriş penceresi çıkarsa'
        Write-Log '     İYTE kurumsal kullanıcı adı ve şifrenizi girin.'
        Write-Log '   • Çıkmazsa: sağ alttaki Wi-Fi simgesi > eduroam > Bağlan.'
        Write-Log '   • Sertifika uyarısı çıkarsa onaylayıp devam edin.'
        return $true
    }
    catch {
        Write-Log "[!] Beklenmeyen hata: $($_.Exception.Message)"
        return $false
    }
}

# ---------------------------------------------------------------------------
# Arayüz
# ---------------------------------------------------------------------------
function Show-Gui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'İYTE eduroam Onarım Aracı'
    $form.ClientSize = New-Object System.Drawing.Size(560, 440)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'eduroam bağlantı sorunu mu var?'
    $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $title.Location = New-Object System.Drawing.Point(16, 14)
    $title.AutoSize = $true

    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = 'Bozuk eduroam profilini siler, güncelini ekler ve bağlanmayı dener. Birkaç saniye sürer.'
    $desc.Location = New-Object System.Drawing.Point(18, 46)
    $desc.Size = New-Object System.Drawing.Size(524, 38)

    $script:ChkDeep = New-Object System.Windows.Forms.CheckBox
    $script:ChkDeep.Text = 'Derin temizlik (DNS temizle, WLAN servisini ve Wi-Fi adaptörünü yeniden başlat)'
    $script:ChkDeep.Location = New-Object System.Drawing.Point(18, 90)
    $script:ChkDeep.Size = New-Object System.Drawing.Size(524, 24)

    $script:BtnRun = New-Object System.Windows.Forms.Button
    $script:BtnRun.Text = 'Onar ve Bağlan'
    $script:BtnRun.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
    $script:BtnRun.Location = New-Object System.Drawing.Point(18, 124)
    $script:BtnRun.Size = New-Object System.Drawing.Size(524, 44)
    $script:BtnRun.FlatStyle = 'System'

    $script:LogBox = New-Object System.Windows.Forms.TextBox
    $script:LogBox.Multiline = $true
    $script:LogBox.ReadOnly = $true
    $script:LogBox.ScrollBars = 'Vertical'
    $script:LogBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $script:LogBox.Location = New-Object System.Drawing.Point(18, 182)
    $script:LogBox.Size = New-Object System.Drawing.Size(524, 200)

    $script:LblStatus = New-Object System.Windows.Forms.Label
    $script:LblStatus.Text = 'Hazır.'
    $script:LblStatus.Location = New-Object System.Drawing.Point(18, 392)
    $script:LblStatus.Size = New-Object System.Drawing.Size(420, 30)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Kapat'
    $btnClose.Location = New-Object System.Drawing.Point(452, 390)
    $btnClose.Size = New-Object System.Drawing.Size(90, 30)
    $btnClose.Add_Click({ $this.FindForm().Close() })

    $script:Sink = {
        param($m)
        $script:LogBox.AppendText($m + "`r`n")
        [System.Windows.Forms.Application]::DoEvents()
    }

    $script:BtnRun.Add_Click({
        $script:Busy = $true
        $script:BtnRun.Enabled = $false
        $script:ChkDeep.Enabled = $false
        $script:LogBox.Clear()
        $script:LblStatus.Text = 'Çalışıyor...'
        [System.Windows.Forms.Application]::DoEvents()

        $ok = Invoke-EduroamFix -Deep $script:ChkDeep.Checked

        if ($ok) { $script:LblStatus.Text = 'Tamamlandı.' }
        else     { $script:LblStatus.Text = 'Sorun oluştu - yukarıdaki mesajlara bakın.' }
        $script:BtnRun.Text = 'Tekrar dene'
        $script:BtnRun.Enabled = $true
        $script:ChkDeep.Enabled = $true
        $script:Busy = $false
    })

    $form.Add_FormClosing({
        param($sender, $e)
        if ($script:Busy) { $e.Cancel = $true }
    })

    $form.Controls.AddRange(@($title, $desc, $script:ChkDeep, $script:BtnRun,
                              $script:LogBox, $script:LblStatus, $btnClose))
    [void]$form.ShowDialog()
}

# ---------------------------------------------------------------------------
# Başlat
# ---------------------------------------------------------------------------
if ($NoGui) {
    Write-Host '=== İYTE eduroam Onarım Aracı ==='
    [void](Invoke-EduroamFix -Deep $false)
    Write-Host ''
    Read-Host 'Çıkmak için Enter'
}
else {
    Show-Gui
}
