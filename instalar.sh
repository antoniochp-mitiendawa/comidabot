#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 1: PREPARACIÓN Y ACTUALIZACIÓN
# PROYECTO: COMIDABOT
# ==========================================

echo -e "\n\e[1;32m[+] Iniciando instalación de ComidaBot...\e[0m"
echo -e "\e[1;34m[+] Configurando repositorios estables...\e[0m"

# Evitar que Termux pregunte qué hacer con archivos de configuración (mantiene los actuales)
export DEBIAN_FRONTEND=noninteractive

# Cambiar a mirrors automáticos para evitar errores de conexión
termux-change-repo <<< "default"

# Actualización del sistema base (silenciosa y automática)
pkg update -y -o Dpkg::Options::="--force-confold"
pkg upgrade -y -o Dpkg::Options::="--force-confold"

echo -e "\e[1;34m[+] Instalando dependencias de Node.js y Git...\e[0m"

# Instalación de paquetes necesarios para el Bloque de Conexión
pkg install nodejs-lts git -y

# Verificar versiones instaladas para el reporte
NODE_VER=$(node -v)
echo -e "\n\e[1;32m------------------------------------------\e[0m"
echo -e "\e[1;32m BLOQUE 1 COMPLETADO CON ÉXITO\e[0m"
echo -e "\e[1;32m Versión de Node: $NODE_VER\e[0m"
echo -e "\e[1;32m------------------------------------------\e[0m"
echo -e "\e[1;33mPróximo paso: Instalación de Baileys y Pairing Code.\e[0m\n"
