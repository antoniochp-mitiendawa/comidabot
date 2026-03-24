#!/data/data/com.termux/files/usr/bin/bash

# 1. Limpieza de seguridad
echo -e "\e[1;32m[+] Limpiando instalaciones previas...\e[0m"
rm -rf node_modules package-lock.json

# 2. Actualización de paquetes críticos
echo -e "\e[1;32m[+] Actualizando entorno de sistema...\e[0m"
pkg update -y && pkg upgrade -y
pkg install -y nodejs-lts git ffmpeg

# 3. Creación de estructura de archivos (Si no existen)
if [ ! -f "package.json" ]; then
    echo -e "\e[1;32m[+] Inicializando proyecto Node.js...\e[0m"
    npm init -y
fi

# 4. Instalación de Baileys y dependencias de red
# Usamos versiones específicas que sabemos que son estables en Termux
echo -e "\e[1;32m[+] Instalando motor de WhatsApp (Baileys)...\e[0m"
npm install @whiskeysockets/baileys pino qrcode-terminal libsignal-node

# 5. Mensaje final de éxito
echo -e "\e[1;34m--------------------------------------------------\e[0m"
echo -e "\e[1;32m Entorno listo. El siguiente paso es crear el index.js \e[0m"
echo -e "\e[1;32m para generar tu código de vinculación (Pairing). \e[0m"
echo -e "\e[1;34m--------------------------------------------------\e[0m"
