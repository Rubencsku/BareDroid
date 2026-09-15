#!/usr/bin/env bash
# ==============================================================================
# 05_server_post_install.sh - Optimización de Debian Server en POCO F4
# Ejecutar directamente dentro del POCO F4 una vez instalado Debian (vía SSH o terminal)
# ==============================================================================
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Este script debe ejecutarse como root (o con sudo)."
    exit 1
fi

echo "=========================================================="
echo "    POCO F4 (munch) - Configuración Debian Server 24/7   "
echo "=========================================================="

echo "[1/7] Actualizando repositorios del sistema..."
apt-get update
apt-get upgrade -y

echo "[2/7] Instalando paquetes esenciales para servidor..."
apt-get install -y \
    curl \
    wget \
    git \
    htop \
    iotop \
    net-tools \
    iproute2 \
    sudo \
    ufw \
    ca-certificates \
    gnupg \
    lsb-release \
    avahi-daemon \
    openssh-server \
    zram-tools \
    wireless-tools \
    wpasupplicant

echo "[3/7] Configurando nombre de host y mDNS (avahi)..."
echo "poco-server" > /etc/hostname
hostname -F /etc/hostname
systemctl enable --now avahi-daemon
echo "[+] Servidor accesible en la red local como: poco-server.local"

echo "[4/7] Instalando Docker Engine y Docker Compose..."
if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    echo "[+] Docker instalado y habilitado."
else
    echo "[+] Docker ya se encuentra instalado."
fi

echo "[5/7] Instalando Nginx Web Server / Reverse Proxy..."
apt-get install -y nginx
systemctl enable --now nginx

# Página de bienvenida informativa
cat <<'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>POCO F4 Linux Server</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
        .card { background: #1e293b; padding: 2.5rem; border-radius: 1rem; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); max-width: 600px; width: 100%; border: 1px solid #334155; }
        h1 { color: #38bdf8; margin-top: 0; font-size: 1.8rem; }
        .badge { display: inline-block; background: #0284c7; color: white; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.85rem; font-weight: 600; margin-bottom: 1rem; }
        .spec { display: flex; justify-content: space-between; padding: 0.5rem 0; border-bottom: 1px solid #334155; font-size: 0.95rem; }
        .spec span:first-child { color: #94a3b8; }
        .spec span:last-child { font-family: monospace; color: #a5f3fc; }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge">Debian ARM64 Headless</span>
        <h1>POCO F4 (munch) Home Server</h1>
        <p>Servidor Linux nativo de alto rendimiento funcionando sobre Qualcomm Snapdragon 870.</p>
        <div class="spec"><span>Arquitectura:</span><span>aarch64 (8 Cores Kryo 585)</span></div>
        <div class="spec"><span>Almacenamiento:</span><span>UFS 3.1 High-Speed Flash</span></div>
        <div class="spec"><span>Servicios:</span><span>Docker, Nginx, OpenSSH</span></div>
        <div class="spec"><span>Batería:</span><span>UPS Integrado Activo</span></div>
    </div>
</body>
</html>
EOF

echo "[6/7] Configurando apagado automático de pantalla AMOLED (Prevención de burn-in)..."
# Desactivar pantalla de consola tras 1 minuto sin pulsación de teclas
cat <<'EOF' > /etc/systemd/system/screen-saver.service
[Unit]
Description=AMOLED Screen Blanker for Phone Server
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'setterm --blank 1 --powerdown 1 > /dev/tty0 2>/dev/null || true; echo 1 > /sys/class/graphics/fb0/blank 2>/dev/null || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable screen-saver.service

echo "[7/7] Configurando optimización de memoria ZRAM (Swap ultrarrápido en RAM)..."
cat <<'EOF' > /etc/default/zramswap
# Asignar el 50% de la RAM como zram swap comprimido con zstd/lz4
PERCENT=50
ALGO=zstd
EOF
systemctl restart zramswap || true

echo ""
echo "=========================================================="
echo "   ¡Configuración del Servidor POCO F4 completada!        "
echo "=========================================================="
echo " - Nginx activo en: http://$(hostname -I | awk '{print $1}')"
echo " - Acceso local mDNS: http://poco-server.local"
echo " - Docker activo: 'docker ps' listo para desplegar contenedores"
echo " - Pantalla: Configurada para apagarse automáticamente"
