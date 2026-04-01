#!/data/data/com.termux/files/usr/bin/bash

echo "---------------------------------------------------------"
echo "INSTALADOR DEFINITIVO COMIDABOT - CORRECCIÓN NDK"
echo "---------------------------------------------------------"

# FASE 1: Preparación con repositorio de herramientas de Termux
pkg update -y && pkg upgrade -y
pkg install -y nodejs git python python-pip wget proot-distro build-essential

# Instalamos sqlite directamente en Termux para evitar errores de compilación en npm
pkg install -y sqlite

# FASE 2: IA LOCAL (Ollama)
if [ ! -d "$HOME/.proot-distro/installed-rootfs/ubuntu" ]; then
    proot-distro install ubuntu
fi
proot-distro login ubuntu -- bash -c "curl -fsSL https://ollama.com/install.sh | sh"
proot-distro login ubuntu -- bash -c "ollama serve > /dev/null 2>&1 & sleep 8 && ollama pull llama3.2:1b"

# FASE 3: Instalación de Librerías de WhatsApp
cd $HOME/comidabot
# Limpiamos instalaciones fallidas previas
rm -rf node_modules package-lock.json
# Instalamos ignorando scripts de compilación nativos que dan error
npm install --no-bin-links --ignore-scripts
# Instalamos Baileys y sus dependencias de forma directa
npm install @whiskeysockets/baileys pino dotenv js-yaml @hapi/boom

# FASE 4: Configuración de Datos
echo "---------------------------------------------------------"
read -p "Introduce el número del BOT (ej. 521XXXXXXXXXX): " BOT_PHONE
read -p "Introduce el número del DUEÑO (ej. 521XXXXXXXXXX): " OWNER_PHONE

echo "OWNER_RAW_NUMBER=$OWNER_PHONE" > .env
echo "BOT_NUMBER=$BOT_PHONE" >> .env
echo "DATABASE_PATH='/data/data/com.termux/files/usr/bin/sqlite3'" >> .env

echo "---------------------------------------------------------"
echo "INSTALACIÓN FINALIZADA. Iniciando ComidaBot..."
node index.js
