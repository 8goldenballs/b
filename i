#!/bin/bash
# бета_забор_i.sh — v1.1 (задача 616; v1.1 — чистка ключа и проверка доступа): первичная установка «сервер сам забирает
# выпуск с GitHub». Запускается на сервере один раз руками в консоли Selectel:
#   wget -O i URL_ЭТОГО_ФАЙЛА ; bash i
# Спросит репозиторий и токен (только чтение; пусто — репозиторий открытый),
# положит `бета_забор.py` и таймер на 5 минут. keys.env не трогает.
# В самом файле кириллицы нет в командах — только в комментариях.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "нужен root"; exit 1; }
read -r -p "repo owner/name: " REPO
read -r -s -p "token (empty if public): " TOK; echo
# v1.1: konsol Selectel pri vstavke dobavlyaet musor (escape, probely) - chistim
TOK=$(printf '%s' "$TOK" | tr -cd 'A-Za-z0-9_')
REPO=$(printf '%s' "$REPO" | tr -cd 'A-Za-z0-9_./-')
if [ -n "$TOK" ]; then
  C=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" https://api.github.com/user)
  [ "$C" = 200 ] || { echo "TOKEN REJECTED ($C): make a new token, paste again"; exit 1; }
  C=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" "https://api.github.com/repos/$REPO")
  [ "$C" = 200 ] || { echo "TOKEN OK, NO ACCESS TO REPO ($C): check repo name / Contents read-only"; exit 1; }
  echo "token OK, repo OK (${#TOK} chars)"
fi
read -r -p "ref [beta-release]: " REF
REF=${REF:-beta-release}
install -d -m 700 /etc/tulza-beta /var/lib/tulza-beta-pull
umask 077
printf 'GITHUB_REPO=%s\nGITHUB_REF=%s\nGITHUB_TOKEN=%s\n' "$REPO" "$REF" "$TOK" > /etc/tulza-beta/pull.env
umask 022
T=$(mktemp -d)
AUTH=()
[ -z "$TOK" ] || AUTH=(-H "Authorization: Bearer $TOK")
curl -fsSL "${AUTH[@]}" -o "$T/s.tgz" "https://api.github.com/repos/$REPO/tarball/$REF"
tar -xzf "$T/s.tgz" -C "$T" --wildcards '*/сервер/бета_забор.py'
install -m 755 "$T"/*/сервер/бета_забор.py /usr/local/sbin/tulza-beta-pull
rm -rf "$T"
cat > /etc/systemd/system/tulza-beta-pull.service <<'UNIT'
[Unit]
Description=tulza beta: pull release from GitHub
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/sbin/tulza-beta-pull
TimeoutStartSec=3000
UNIT
cat > /etc/systemd/system/tulza-beta-pull.timer <<'UNIT'
[Unit]
Description=tulza beta: pull every 5 min
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now tulza-beta-pull.timer
systemctl start --no-block tulza-beta-pull.service
echo "ok: status in /var/lib/tulza-beta-pull/status.json"
