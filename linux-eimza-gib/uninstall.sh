#!/usr/bin/env bash
# Kurulumu geri alır. Sistem paketlerine (pcscd, opensc...) dokunmaz.
set -u
BASE="${XDG_DATA_HOME:-$HOME/.local/share}"

systemctl --user disable --now efatura-imza 2>/dev/null || true
"$HOME/.local/bin/efatura-imza" stop 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/efatura-imza.service" "$HOME/.local/bin/efatura-imza"
modutil -dbdir "sql:$HOME/.pki/nssdb" -delete Akis -force 2>/dev/null || true
[ -L /usr/lib/libakisp11.so ] && sudo rm -f /usr/lib/libakisp11.so
rm -rf "$BASE/akis" "$BASE/efatura-ws" "$BASE/java8"
echo "Kaldırıldı. (Firefox'taki 'Akis' güvenlik cihazını elle sil: Ayarlar > Güvenlik Cihazları.)"
