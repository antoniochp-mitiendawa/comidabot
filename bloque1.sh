#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 1: INSTALACIÓN DE MOTOR Y LIBRERÍAS
# PROYECTO: COMIDABOT - INSTALACIÓN DESDE CERO
# ==========================================

echo -e "\n\e[1;32m[+] Iniciando CONFIGURACIÓN DEL MOTOR (Bloque 1)...\e[0m"

# Evitar interrupciones manuales
export DEBIAN_FRONTEND=noninteractive

echo -e "\e[1;34m[+] Instalando Node.js LTS y dependencias de red...\e[0m"
# Instalamos Node.js (el motor) y aseguramos que las herramientas de compilación estén presentes
pkg install nodejs-lts -y -o Dpkg::Options::="--force-confold"

echo -e "\e[1;34m[+] Creando estructura de directorios en el Home...\e[0m"
# Creamos la carpeta del bot y entramos en ella
mkdir -p $HOME/comidabot
cd $HOME/comidabot

echo -e "\e[1;34m[+] Inicializando entorno de Node (Package Manager)...\e[0m"
# Creamos el archivo package.json base de forma automática
npm init -y

echo -e "\e[1;34m[+] Instalando Baileys y librerías de conexión de WhatsApp...\e[0m"
# Instalamos la librería de conexión (Baileys), el gestor de logs (Pino) y el generador de QR
npm install @whiskeysockets/baileys pino qrcode-terminal --no-audit --no-fund

echo -e "\n\e[1;32m------------------------------------------\e[0m"
echo -e "\e[1;32m BLOQUE 1: MOTOR Y LIBRERÍAS INSTALADOS\e[0m"
echo -e "\e[1;32m Estado: LISTO PARA EMPAREJAMIENTO\e[0m"
echo -e "\e[1;32m------------------------------------------\e[0m"
echo -e "\e[1;33mPróximo paso: Bloque 2 (Script de Pairing Code).\e[0m\n"
