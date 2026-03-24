#!/data/data/com.termux/files/usr/bin/bash

# Mensaje de inicio
echo -e "\e[1;34m[*] INICIANDO INSTALACIÓN BLINDADA - PROYECTO COMIDABOT\e[0m"

# 1. Actualización y Wake Lock (Evita que el sistema duerma a Termux)
pkg update -y && pkg upgrade -y
pkg install -y termux-api
termux-wake-lock

# 2. Instalación de herramientas base y FFmpeg
echo -e "\e[1;32m[+] Instalando Node.js, Git y FFmpeg...\e[0m"
pkg install -y nodejs-lts git ffmpeg

# 3. Limpieza de seguridad y preparación de carpetas
rm -rf node_modules package-lock.json sesion_auth base_datos.json
npm init -y
npm install @whiskeysockets/baileys pino qrcode-terminal libsignal-node fluent-ffmpeg

# 4. Creación de la Memoria Local (Estructura extendida para Spintax)
echo '{"bot_num": null, "propietario_num": null, "nombre_negocio": "Negocio", "menu": "No configurado", "horario": "No configurado"}' > base_datos.json

# 5. CREACIÓN DEL EJECUTOR AUTOMÁTICO (Para no escribir "node index.js" siempre)
echo "node index.js" > start.sh
chmod +x start.sh

echo -e "\e[1;34m--------------------------------------------------\e[0m"
echo -e "\e[1;32m INSTALACIÓN COMPLETADA CON ÉXITO \e[0m"
echo -e "\e[1;32m El Wake Lock ha sido activado. \e[0m"
echo -e "\e[1;32m Para iniciar usa: ./start.sh \e[0m"
echo -e "\e[1;34m--------------------------------------------------\e[0m"
