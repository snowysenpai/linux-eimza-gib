# Linux'ta Akis e-imza + GİB imza aracı

Akis (TÜBİTAK/Kamu SM) e-imza kartını **Fedora / Ubuntu** üzerinde, GİB e-Fatura / e-Defter / e-Arşiv
portallarında kullanmak için hazır kurulum. ACS ACR39U okuyucu ve Akis kartla denendi.

> Bu repo yalnızca kurulum betiklerini içerir. Akis sürücüsü, GİB imza aracı ve Java kendi resmi
> kaynaklarından indirilir; repoya konmaz.

## Neden bu kadar uğraş gerekiyor?

| Sorun | Sebep | Çözüm |
|---|---|---|
| Kart "token not recognized" | Linux'ta Akis sürücüsü yok | Ubuntu paketinden `libakisp11.so` alınır |
| "Elektronik imza uygulaması yükleniyor" sonsuz bekler | GİB'in eski giriş sayfası Java applet kullanır, tarayıcılar yıllar önce kaldırdı | "İmzalama aracı" (yerel websocket) yolu kullanılır |
| "İmza socket sunucusuna erişilemedi" | İmza aracı çalışmıyor (JNLP açacak `javaws` yok) | Jar'lar JNLP'den indirilip `java -cp` ile çalıştırılır |
| Sayfa araca bağlanamıyor | Araç `https://localhost:8543` üzerinde kendi imzaladığı sertifikayı sunar | Tarayıcıda bir kez "riski kabul et" |
| "Akıllı kartınızda sertifikaya erişilemedi" (PIN doğru olsa bile) | Araç `SunPKCS11(InputStream)` kurucusunu kullanır, **Java 9+'da yok** | **Java 8** ile çalıştırılır |
| Araç kartı bulamıyor | Sürücüyü sabit `/usr/lib/libakisp11.so` yolunda arar | Bu yola symlink |
| Java 17 ile `localhost` açılmıyor | Eski Jetty 9.0.4 + yeni Java TLS uyumsuzluğu | Java 8 kullanıldığı için yok |
| "İmza atılması sırasında hata… internet bağlantı ayarları" | **Yanıltıcı mesaj.** Çoğunlukla sertifika **süresi dolmuş** | Sertifikayı yenile (aşağıya bak) |

## Kurulum

1. Akis paketini indir (kartı aldığın kurumun "E-imza Kurulum Sürücüleri" sayfası):
   **Akis Yönetici Paketi → Ubuntu v16.04 64 bit** satırı. (Dosya bir `.zip` içinde `.deb` gelir.)
2. Çalıştır:
   ```bash
   ./install.sh ~/İndirilenler/E-imzatr_Ubuntu_v1604_64_bit
   ```
   `sudo` sadece paket kurmak ve `/usr/lib/libakisp11.so` bağlantısı için istenir.
3. Kartı tak, kontrol et:
   ```bash
   pkcs11-tool --module ~/.local/share/akis/libakisp11.so -O
   ```
   Sertifikanı listelemeli.
4. İmza aracını başlat:
   ```bash
   efatura-imza start
   ```
   Açılışta otomatik başlasın istersen: `systemctl --user enable --now efatura-imza`
5. Tarayıcıda **bir kez** `https://localhost:8543` aç → *Gelişmiş → Riski kabul et ve devam et*.
   "Gelir İdaresi Başkanlığı imzalama aracına hoş geldiniz" yazısı görünmeli.
6. e-Fatura girişi (eski applet sayfası **değil**, imzalama aracı yolu):
   <https://portal.efatura.gov.tr/efatura/wsctgirisSSL.jsp>

Firefox için ayrıca: *Ayarlar → Gizlilik ve Güvenlik → Güvenlik Cihazları → Yükle* →
`~/.local/share/akis/libakisp11.so`. (Chrome/Chromium için betik bunu otomatik yapar.)

## Sorun giderme

- `efatura-imza status` / `efatura-imza log`; ayrıntılı log: `/tmp/EFaturaWebSocketLog/`
- Firefox: F12 → Ağ → WS → Mesajlar, sayfanın araca ne gönderdiğini gösterir (**PIN'i paylaşmadan önce sil**).
- İmza sırasında hata alıyorsan logda şunu ara: `GEÇERSİZ!...[başlangıç - bitiş]`.
  Bitiş tarihi geçmişse sorun kurulum değil, **sertifikan bitmiştir**; kartı veren kurumdan yenile.
- PIN'i üst üste yanlış deneme; kart kilitlenebilir. Hata mesajı PIN hatası gibi görünse de çoğu zaman değildir.

## Güvenlik notları

- GİB imza aracı Windows'taki gibi tam yetkiyle Java kodu çalıştırır; betik jar'ları yalnızca
  `ebelge.gib.gov.tr` adresinden indirir. Yine de ne çalıştırdığını bil.
- Araç yalnızca `127.0.0.1:8543`'te dinler, dışarıya açık değildir.
- Betik kişisel veri içermez, PIN istemez. Kendi bilgilerini issue/PR'a yazma.

## Kaldırma

```bash
./uninstall.sh
```

## Lisans / sorumluluk reddi

Betikler olduğu gibi sunulur, **garanti yoktur** (lisans eklemek için `LICENSE` dosyası koy). Akis, GİB imza aracı ve Temurin kendi
sahiplerinin lisansları altındadır. Resmî bir destek değildir.
