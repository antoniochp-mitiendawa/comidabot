#!/data/data/com.termux/files/usr/bin/bash

# Mensaje de inicio
echo -e "\e[1;34m[*] INICIANDO INSTALACIÓN MAESTRA - PROYECTO COMIDABOT\e[0m"

# 1. Actualización total del sistema Termux
echo -e "\e[1;32m[+] Actualizando repositorios y paquetes...\e[0m"
pkg update -y && pkg upgrade -y

# 2. Instalación de herramientas base y FFmpeg
echo -e "\e[1;32m[+] Instalando Node.js, Git y FFmpeg...\e[0m"
pkg install -y nodejs-lts git ffmpeg

# 3. Limpieza de seguridad
echo -e "\e[1;32m[+] Limpiando entorno previo...\e[0m"
rm -rf node_modules package-lock.json sesion_auth base_datos.json

# 4. Inicialización de Node.js y dependencias
echo -e "\e[1;32m[+] Instalando librerías de WhatsApp...\e[0m"
npm init -y
npm install @whiskeysockets/baileys pino qrcode-terminal libsignal-node fluent-ffmpeg

# 5. Creación de la base de datos local (Estructura de Doble Mando)
echo '{"bot_num": null, "propietario_num": null, "nombre_negocio": "No configurado", "menu": "No hay menú", "horario": "No configurado"}' > base_datos.json
echo -e "\e[1;32m[+] Memoria local inicializada.\e[0m"

echo -e "\e[1;34m--------------------------------------------------\e[0m"
echo -e "\e[1;32m INSTALACIÓN COMPLETADA CON ÉXITO \e[0m"
echo -e "\e[1;32m Ejecuta: node index.js \e[0m"
echo -e "\e[1;34m--------------------------------------------------\e[0m"
