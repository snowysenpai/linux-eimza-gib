#!/usr/bin/env bash
# Linux (Fedora/Ubuntu) üzerinde Akis e-imza kartı + GİB imza aracı kurulumu.
# Kullanım:  ./install.sh /yol/E-imzatr_Ubuntu_v1604_64_bit      (Akis paketi: .zip veya .deb)
set -euo pipefail

AKIS_PKG="${1:-}"
BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
AKIS_DIR="$BASE/akis"
GIB_DIR="$BASE/efatura-ws"
JAVA_DIR="$BASE/java8"
GIB_URL="https://ebelge.gib.gov.tr/EFaturaWebSocket"
JAVA_URL="https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jre/hotspot/normal/eclipse"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

[ -n "$AKIS_PKG" ] && [ -f "$AKIS_PKG" ] || die "Akis paketinin yolunu ver.
  1) https://www.kamusm.gov.tr  (veya kartı aldığın firmanın 'E-imza Kurulum Sürücüleri' sayfası)
  2) 'Akis Yönetici Paketi' -> 'Ubuntu v16.04 64 bit' satırını indir
  3) ./install.sh ~/İndirilenler/E-imzatr_Ubuntu_v1604_64_bit"

for c in curl unzip ar tar; do command -v "$c" >/dev/null || die "'$c' gerekli (kurulu değil)."; done

# ---------------------------------------------------------------- 1) Sistem paketleri
say "1/6 Akıllı kart altyapısı (pcscd, ccid, opensc)"
if command -v dnf >/dev/null; then
  sudo dnf install -y pcsc-lite pcsc-lite-ccid opensc nss-tools
elif command -v apt-get >/dev/null; then
  sudo apt-get update && sudo apt-get install -y pcscd libccid opensc libnss3-tools
else
  warn "Paket yöneticisi tanınmadı; pcscd, ccid, opensc, nss-tools'u elle kur."
fi
sudo systemctl enable --now pcscd.socket pcscd 2>/dev/null || sudo systemctl enable --now pcscd || true

# ---------------------------------------------------------------- 2) Akis kütüphanesi
say "2/6 Akis PKCS#11 kütüphanesi"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/pkg" "$TMP/deb"
if file "$AKIS_PKG" | grep -qi 'zip'; then
  unzip -oq "$AKIS_PKG" -d "$TMP/pkg"
  DEB="$(find "$TMP/pkg" -name '*.deb' | head -1)"
  [ -n "$DEB" ] || die "Zip içinde .deb bulunamadı."
else
  DEB="$AKIS_PKG"
fi
( cd "$TMP/deb" && ar x "$DEB" && tar xf data.tar.* )
SO="$(find "$TMP/deb" -name libakisp11.so | head -1)"
[ -n "$SO" ] || die "libakisp11.so pakette bulunamadı."
mkdir -p "$AKIS_DIR"
install -m 0644 "$SO" "$AKIS_DIR/libakisp11.so"
echo "Kopyalandı: $AKIS_DIR/libakisp11.so"

# İmza aracı sürücüyü sabit olarak /usr/lib/libakisp11.so yolunda arıyor.
sudo ln -sf "$AKIS_DIR/libakisp11.so" /usr/lib/libakisp11.so
echo "Bağlantı: /usr/lib/libakisp11.so -> $AKIS_DIR/libakisp11.so"

# ---------------------------------------------------------------- 3) Java 8
say "3/6 Java 8 (taşınabilir, sistemi değiştirmez)"
# GİB imza aracı SunPKCS11(InputStream) kurucusunu kullanıyor; bu sadece Java 8'de var.
JAVA_BIN="$(find "$JAVA_DIR" -maxdepth 3 -path '*/bin/java' -type f 2>/dev/null | head -1)"
if [ -z "$JAVA_BIN" ]; then
  mkdir -p "$JAVA_DIR"
  curl -fL --progress-bar -o "$JAVA_DIR/jre8.tar.gz" "$JAVA_URL"
  tar xzf "$JAVA_DIR/jre8.tar.gz" -C "$JAVA_DIR"
  rm -f "$JAVA_DIR/jre8.tar.gz"
fi
JAVA_BIN="$(find "$JAVA_DIR" -maxdepth 3 -path '*/bin/java' -type f | head -1)"
[ -n "$JAVA_BIN" ] || die "Java 8 kurulamadı."
"$JAVA_BIN" -version 2>&1 | head -1

# ---------------------------------------------------------------- 4) GİB imza aracı
say "4/6 GİB imza aracı (resmi adres: ebelge.gib.gov.tr)"
mkdir -p "$GIB_DIR/lib"
JNLP="$(curl -fsSL "$GIB_URL/EFaturaWebSocket.jnlp")"
MAIN="$(printf '%s' "$JNLP" | grep -oE 'main-class="[^"]+"' | head -1 | sed 's/main-class="//;s/"$//')"
[ -n "$MAIN" ] || die "JNLP içinde main-class bulunamadı."
printf '%s' "$MAIN" > "$GIB_DIR/main-class"
printf '%s' "$JNLP" | grep -oE 'href="[^"]+\.jar"' | sed 's/href="//;s/"$//' | while read -r jar; do
  mkdir -p "$GIB_DIR/$(dirname "$jar")"
  curl -fsSL -o "$GIB_DIR/$jar" "$GIB_URL/$jar" && echo "  indirildi: $jar"
done

# ---------------------------------------------------------------- 5) Başlatma betikleri
say "5/6 Başlatma betikleri"
mkdir -p "$HOME/.local/bin"
install -m 0755 "$HERE/bin/efatura-imza" "$HOME/.local/bin/efatura-imza"
mkdir -p "$HOME/.config/systemd/user"
install -m 0644 "$HERE/systemd/efatura-imza.service" "$HOME/.config/systemd/user/efatura-imza.service"
systemctl --user daemon-reload 2>/dev/null || true
echo "Komut: efatura-imza {start|stop|status|log}   (PATH'te ~/.local/bin olmalı)"

# ---------------------------------------------------------------- 6) Tarayıcılar
say "6/6 Tarayıcı (Chrome/Chromium) kart modülü"
NSSDB="$HOME/.pki/nssdb"
if command -v modutil >/dev/null; then
  mkdir -p "$NSSDB"
  [ -f "$NSSDB/cert9.db" ] || certutil -N -d "sql:$NSSDB" --empty-password
  if modutil -dbdir "sql:$NSSDB" -list 2>/dev/null | grep -q 'Akis'; then
    echo "Akis modülü zaten ekli."
  else
    modutil -dbdir "sql:$NSSDB" -add Akis -libfile "$AKIS_DIR/libakisp11.so" -force </dev/null || warn "Modül eklenemedi."
  fi
fi

cat <<EOF

Kurulum bitti.

Sıradaki adımlar:
  1) Kartı okuyucuya tak ve test et:   pkcs11-tool --module $AKIS_DIR/libakisp11.so -O
  2) İmza aracını başlat:              efatura-imza start
  3) Firefox/Chrome'da bir kez aç:     https://localhost:8543
     -> "Riski kabul et ve devam et" de (GİB'in kendi yerel sertifikası).
  4) e-Fatura girişi:                  https://portal.efatura.gov.tr/efatura/wsctgirisSSL.jsp
  5) Firefox'ta ayrıca: Ayarlar > Güvenlik Cihazları > Yükle > $AKIS_DIR/libakisp11.so

Açılışta otomatik başlatmak için:      systemctl --user enable --now efatura-imza
EOF
