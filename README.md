# İYTE eduroam Onarım Aracı

Windows 10/11'de **eduroam bağlantı sorunlarını tek tıkla** gideren, küçük ve açık kaynaklı bir araç.

> ⚠️ **Resmî bir İYTE aracı değildir.** Bağımsız bir öğrenci projesidir. eduroam profil yapılandırması, İYTE'nin yayımladığı resmî eduroam profiline dayanır. Resmî destek için İYTE Bilgi İşlem Daire Başkanlığı'na (BİDB) başvurun.

---

## Ne işe yarar?

Windows bazen eduroam profilini bozar: şifre değiştirdikten sonra bağlanamazsınız, sürekli şifre sorar, listede `eduroam 2` gibi çift profiller oluşur ya da "Bu ağa bağlanılamıyor" hatası alırsınız.

Bu araç bozuk profili temizler, doğru profili yeniden ekler ve bağlanmayı dener. Birkaç saniye sürer.

## Nasıl kullanılır?

1. Sağdaki **Releases** bölümünden en son sürümün **`IYTE-Eduroam-Onar.zip`** dosyasını indirin.
   *(Alternatif: **Code → Download ZIP**.)*
2. ZIP'e **sağ tık → Tümünü ayıkla** ile bir klasöre çıkarın. *(ZIP'in içinden doğrudan çalıştırmayın.)*
3. **`Eduroam-Onar.bat`** dosyasına **çift tıklayın.**
   > `IYTE-Eduroam-Onar.ps1` dosyasına çift tıklamayın: Windows `.ps1` dosyalarını çalıştırmaz, Not Defteri'nde açar. `.bat` dosyası onu sizin için doğru şekilde başlatır.
4. "Bu uygulamanın cihazınızda değişiklik yapmasına izin vermek istiyor musunuz?" sorusuna **Evet** deyin (yönetici izni, Wi-Fi profili işlemleri için gerekir).
5. **Onar ve Bağlan** butonuna basın.
6. Ekranın sağ altında giriş penceresi çıkarsa İYTE kurumsal kullanıcı adı ve şifrenizi **Windows'un kendi penceresine** girin.

Arayüz istemezseniz konsol modu: `Eduroam-Onar.bat /quick`

**SmartScreen uyarısı çıkarsa** ("Windows bilgisayarınızı korudu"): *Ek bilgi → Yine de çalıştır*. İnternetten indirilen imzasız betiklerde bu normaldir. Kodun tamamı açık, çalıştırmadan önce okuyabilirsiniz.
**Çalışmazsa:** ZIP'e sağ tık → Özellikler → en altta **Engellemeyi kaldır**'ı işaretleyin, sonra ZIP'i çıkarın.

### İndirmeyi doğrulama (isteğe bağlı)

Release açıklamasında ZIP'in **SHA-256** özeti yazar. İndirdiğiniz dosyanın değişmediğini şöyle kontrol edebilirsiniz:

```powershell
Get-FileHash .\IYTE-Eduroam-Onar.zip -Algorithm SHA256
```

Çıkan değer release açıklamasındakiyle birebir aynı olmalı. Farklıysa dosyayı çalıştırmayın. **Aracı yalnızca bu repodan indirin.** "İYTE eduroam aracı" adıyla başka yerlerde dolaşan kopyalar değiştirilmiş olabilir.

## Nasıl çalışır?

| Adım | Ne yapar |
|---|---|
| 1/5 | Wi-Fi donanımını ve WLAN AutoConfig hizmetini kontrol eder; kapalıysa açar. |
| 2/5 | *(İsteğe bağlı "Derin temizlik")* DNS önbelleğini temizler, WLAN servisini ve Wi-Fi adaptörünü yeniden başlatır. |
| 3/5 | `eduroam` ile başlayan **tüm** eski profilleri siler (`eduroam 2` gibi çiftler dahil). |
| 4/5 | Güncel eduroam profilini (PEAP / MSCHAPv2) ekler. |
| 5/5 | eduroam'a bağlanmayı dener ve sonucu kontrol eder. |

Araç `netsh wlan` komutlarını kullanır. Bunlar Windows'un kendi araçlarıdır. Ek yazılım kurulmaz.

## Neden işe yarar?

Windows, eduroam için kullanıcı adı ve şifreyi **profilin içinde** önbelleğe alır. Şifre değiştiğinde ya da profil bozulduğunda Windows eski bilgiyle denemeyi sürdürür ve bağlanamazsınız. Profili silmek önbelleğe alınmış bilgiyi de siler; temiz bir profil eklemek Windows'u sıfırdan başlatır. Çoğu eduroam sorunu bu yüzden tek bir profil sıfırlamasıyla çözülür.

## Ne zaman kullanılmalı?

- Şifre değiştirdikten sonra eduroam bağlanmıyorsa
- Sürekli şifre soruyor ama bağlanmıyorsa
- "Bu ağa bağlanılamıyor" hatası alıyorsanız
- Listede `eduroam 2`, `eduroam 3` gibi çift profiller varsa
- Windows güncellemesinden sonra eduroam bozulduysa

**İşe yaramayacağı durumlar:** Kullanıcı adı/şifreniz yanlışsa veya hesabınız kilitliyse, kampüste kapsama yoksa, Wi-Fi donanımınız bozuksa ya da ağda genel bir kesinti varsa. Bu durumlarda BİDB'ye başvurun.

## Kimler için uygundur?

- Windows 10 / 11 kullanan İYTE öğrencileri ve personeli
- Aynı sorunu defalarca elle çözmekten yorulan herkes

**Uygun değil:** macOS, Linux, Android, iOS. Bu araç yalnızca Windows içindir. Başka üniversitelerin eduroam ayarlarıyla test edilmemiştir.

## Resmî betikle fark

| | Resmî `eduroam.bat` | Bu araç |
|---|---|---|
| Çalıştırma | Birkaç kez tuşa basmak gerekir | Tek tık |
| Silinen profil | Yalnızca tam olarak `eduroam` | `eduroam*` (çift profiller dahil) |
| Wi-Fi hizmeti/adaptör kontrolü | Yok | Var, kapalıysa açar |
| Bağlantı sonucunu kontrol | Yok | Var |
| Derin temizlik | Yok | İsteğe bağlı |
| Arayüz ve günlük çıktısı | Yok | Var |
| **Sunucu sertifika doğrulaması** | **Kapalı** | **Kapalı** (bkz. aşağısı) |

## Güvenlik notu

Profil, İYTE'nin resmî profilindeki gibi `PerformServerValidation=false` ayarını taşır; yani Wi-Fi sunucusunun sertifikası **doğrulanmaz**. Bu, kampüste biri sahte bir "eduroam" ağı açarsa cihazınızın kimlik bilgilerini o ağa verebileceği anlamına gelir (*evil twin* saldırısı). Bu araç bunu **daha güvenli yapmaz**; resmî profille aynı düzeydedir.

Bunu iyileştirmek için İYTE'nin RADIUS sunucu adı ve kök sertifikası profile eklenebilir. Bu bilgiyi BİDB'den doğrulayarak almak gerekir. Katkı ve öneriler memnuniyetle karşılanır.

## Gizlilik

Bu betik internetten **hiçbir şey indirmez**, **hiçbir yere veri göndermez**. Kullanıcı adı ve şifrenizi **görmez, saklamaz**; bunları yalnızca Windows'un kendi giriş penceresine siz yazarsınız. Profil XML'i geçici olarak `C:\Windows\Temp` içine yazılır ve işlem biter bitmez silinir.

## Geri alma

Araç yalnızca `eduroam` Wi-Fi profilini siler/ekler. Profili elle kaldırmak için:

```
netsh wlan delete profile name=eduroam
```

## Dosyalar

| Dosya | Açıklama |
|---|---|
| `Eduroam-Onar.bat` | Başlatıcı. Sadece `.ps1` dosyasını çalıştırır. |
| `IYTE-Eduroam-Onar.ps1` | Asıl araç (tüm kod açık). |
| `LICENSE` | MIT Lisansı |

## Lisans ve atıf

Bu projenin kodu **MIT Lisansı** ile paylaşılmıştır (bkz. [LICENSE](LICENSE)). Telif: © 2026 MTYOURMIND.

eduroam Wi-Fi profili yapılandırması, İYTE Bilgi İşlem Daire Başkanlığı'nın yayımladığı resmî eduroam profiline dayanır. Bu kısım İYTE'ye aittir ve MIT lisansı bu kısmı kapsamaz. Proje, İYTE ile bağlantılı değildir ve İYTE tarafından onaylanmamıştır. "eduroam" ismi ilgili hak sahiplerine aittir.

## Sorumluluk reddi

Yazılım "olduğu gibi" sunulur, herhangi bir garanti verilmez. Kullanım sorumluluğu size aittir.
