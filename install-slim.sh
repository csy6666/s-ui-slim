#!/bin/sh
set -eu

# One-command installer for Alpine Linux. The target host only downloads a
# prebuilt slim binary; it never installs Go, Node.js or a compiler.
REPO="${SUI_SLIM_REPO:-csy6666/s-ui-slim}"
VERSION="${SUI_SLIM_VERSION:-latest}"
PREFIX="${SUI_SLIM_PREFIX:-/usr/local/s-ui-slim}"
SERVICE="${SUI_SLIM_SERVICE:-s-ui-slim}"
PANEL_PORT="${SUI_SLIM_PORT:-}"
SUB_PORT="${SUI_SLIM_SUB_PORT:-}"

say() { printf '%s\n' "[s-ui-slim] $*"; }
die() { printf '%s\n' "[s-ui-slim] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "请使用 root 权限运行。"
[ -f /etc/alpine-release ] || die "此安装器只支持 Alpine Linux。"

case "$PANEL_PORT" in ''|*[!0-9]*) [ -z "$PANEL_PORT" ] || die "SUI_SLIM_PORT 必须是数字。" ;; esac
case "$SUB_PORT" in ''|*[!0-9]*) [ -z "$SUB_PORT" ] || die "SUI_SLIM_SUB_PORT 必须是数字。" ;; esac

apk add --no-cache ca-certificates wget tar gzip >/dev/null

case "$(uname -m)" in
    x86_64|amd64) ASSET_ARCH=amd64 ;;
    aarch64|arm64) ASSET_ARCH=arm64 ;;
    armv7l|armv7) ASSET_ARCH=armv7 ;;
    *) die "暂不支持 CPU 架构: $(uname -m)，目前支持 amd64、arm64、armv7。" ;;
esac

if [ "$VERSION" = "latest" ]; then
    API="https://api.github.com/repos/${REPO}/releases/latest"
    VERSION=$(wget -qO- "$API" | awk -F'"' '/"tag_name"[[:space:]]*:/ { print $4; exit }') || true
    [ -n "$VERSION" ] || die "无法获取最新版本，请设置 SUI_SLIM_VERSION，例如 slim-v0.1.0。"
fi

TMP=$(mktemp -d /tmp/s-ui-slim.XXXXXX)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

BASE="https://github.com/${REPO}/releases/download/${VERSION}"
ASSET="s-ui-slim-linux-${ASSET_ARCH}.tar.gz"
ARCHIVE="$TMP/$ASSET"
SUMS="$TMP/SHA256SUMS"

say "下载 ${REPO} ${VERSION} (${ASSET_ARCH})..."
wget -q -O "$ARCHIVE" "$BASE/$ASSET" || die "下载失败，请检查版本、架构和 GitHub 网络连通性。"
wget -q -O "$SUMS" "$BASE/SHA256SUMS" || die "缺少 SHA256SUMS，拒绝安装未校验的文件。"

EXPECTED=$(awk -v file="$ASSET" '$2 == file || $2 == "*" file { print $1; exit }' "$SUMS")
[ -n "$EXPECTED" ] || die "SHA256SUMS 中没有 ${ASSET}。"
ACTUAL=$(sha256sum "$ARCHIVE" | awk '{print $1}')
[ "$EXPECTED" = "$ACTUAL" ] || die "SHA256 校验失败，已停止安装。"
say "SHA256 校验通过。"

mkdir -p "$TMP/unpack"
tar -xzf "$ARCHIVE" -C "$TMP/unpack"
BIN=$(find "$TMP/unpack" -type f -name sui | head -n 1)
[ -n "$BIN" ] || die "安装包中没有可执行文件 sui。"

if ! grep -q '^sui:' /etc/group 2>/dev/null; then
    addgroup -S sui
fi
if ! id -u sui >/dev/null 2>&1; then
    adduser -S -D -H -s /sbin/nologin -G sui sui
fi

if [ -f "/etc/init.d/$SERVICE" ]; then
    rc-service "$SERVICE" stop >/dev/null 2>&1 || true
fi

mkdir -p "$PREFIX/db"
install -m 0755 "$BIN" "$PREFIX/sui"
cat > "$TMP/service" <<EOF
#!/sbin/openrc-run

name="${SERVICE}"
description="S-UI slim panel for low-memory Alpine hosts"
command="${PREFIX}/sui"
command_user="sui:sui"
directory="${PREFIX}"
pidfile="/run/${SERVICE}.pid"
output_log="/var/log/${SERVICE}.log"
error_log="/var/log/${SERVICE}.err"
command_background="yes"
respawn_delay=5
export SUI_DB_FOLDER="${PREFIX}/db"
export SUI_LOG_LEVEL="\${SUI_LOG_LEVEL:-warn}"

depend() {
    need net
    use logger
}
EOF
install -m 0755 "$TMP/service" "/etc/init.d/$SERVICE"
chown -R sui:sui "$PREFIX"

if [ -n "$PANEL_PORT" ] || [ -n "$SUB_PORT" ]; then
    SETTING_ARGS=""
    [ -z "$PANEL_PORT" ] || SETTING_ARGS="$SETTING_ARGS -port $PANEL_PORT"
    [ -z "$SUB_PORT" ] || SETTING_ARGS="$SETTING_ARGS -subPort $SUB_PORT"
    # shellcheck disable=SC2086
    SUI_DB_FOLDER="$PREFIX/db" "$PREFIX/sui" setting $SETTING_ARGS >/dev/null
fi

rc-update add "$SERVICE" default >/dev/null 2>&1 || true
rc-service "$SERVICE" restart >/dev/null

PORT="$PANEL_PORT"
[ -n "$PORT" ] || PORT=2095
IP=$(hostname -i 2>/dev/null | awk '{print $1}') || IP=
[ -n "$IP" ] || IP="服务器IP"
say "安装完成，服务已启动。"
say "面板地址: http://${IP}:${PORT}/app/"
say "默认登录: admin / admin（首次登录后请立即修改）"
say "服务管理: rc-service ${SERVICE} {start|stop|restart|status}"
