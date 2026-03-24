#!/data/data/com.termux/files/usr/bin/bash

# Mensaje de inicio
echo -e "\e[1;34m[*] INICIANDO INSTALACIÓN MAESTRA COMPLETA - PROYECTO COMIDABOT\e[0m"

# 1. Wake Lock y Actualización Total
# Garantizamos que el sistema no mate el proceso y actualizamos todo
pkg update -y && pkg upgrade -y
pkg install -y termux-api
termux-wake-lock

# 2. Instalación de Herramientas de Sistema
echo -e "\e[1;32m[+] Instalando Node.js, Git, FFmpeg y librerías de compilación...\e[0m"
pkg install -y nodejs-lts git ffmpeg build-essential python

# 3. Limpieza y Reconstrucción del Entorno (Blindaje de archivos)
echo -e "\e[1;32m[+] Preparando directorio y dependencias...\e[0m"
rm -rf node_modules package-lock.json sesion_auth base_datos.json
npm init -y

# 4. Instalación de Dependencias de WhatsApp (Versión Completa)
# Incluimos pino para logs, terminal-qrcode, y libsignal para el cifrado
npm install @whiskeysockets/baileys pino qrcode-terminal libsignal-node fluent-ffmpeg

# 5. Creación de la Memoria Local (Campos para el Dueño y Configuración)
echo '{"bot_num": null, "propietario_num": null, "nombre_negocio": "Negocio", "menu": "No configurado", "horario": "No configurado"}' > base_datos.json

echo -e "\e[1;32m[+] Instalación finalizada con éxito.\e[0m"
echo -e "\e[1;32m[*] Iniciando el servicio de forma automática...\e[0m"

# 6. EJECUCIÓN AUTOMÁTICA
node index.js
