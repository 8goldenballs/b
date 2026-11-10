#!/bin/bash
# бета_забор_i.sh — v1.0 (задача 616): первичная установка «сервер сам забирает
# выпуск с GitHub». Запускается на сервере один раз руками в консоли Selectel:
#   wget -O i URL_ЭТОГО_ФАЙЛА ; bash i
# Спросит репозиторий и токен (только чтение; пусто — репозиторий открытый),
# положит `бета_забор.py` и таймер на 5 минут. keys.env не трогает.
# В самом файле кириллицы нет в командах — только в комментариях.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "нужен root"; exit 1; }
read -r -p "repo owner/name: " REPO
read -r -s -p "token (empty if public): " TOK; echo
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
