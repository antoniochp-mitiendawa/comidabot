#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 0: SANEAMIENTO Y WAKE LOCK (BASE)
# PROYECTO: COMIDABOT - INSTALACIÓN DESDE CERO
# ==========================================

echo -e "\n\e[1;32m[+] Activando Wake Lock (Mantener despierto)...\e[0m"
termux-wake-lock

echo -e "\e[1;34m[+] Configurando Espejos Oficiales de Termux...\e[0m"
# Forzamos los repositorios principales para evitar errores de enlace (Linker errors)
printf "deb https://packages.termux.dev/apt/termux-main/ stable main" > $PREFIX/etc/apt/sources.list

# Evitar preguntas manuales durante la actualización
export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y -o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confnew'"

echo -e "\e[1;34m[+] Actualizando base de datos de paquetes...\e[0m"
apt update $APT_OPTS

echo -e "\e[1;34m[+] Sincronizando librerías de seguridad (SSL/CA)...\e[0m"
# Actualizamos primero lo que rompe a curl
apt install openssl ca-certificates $APT_OPTS

echo -e "\e[1;34m[+] Ejecutando Upgrade Completo del Sistema...\e[0m"
apt full-upgrade $APT_OPTS

echo -e "\e[1;34m[+] Instalando herramientas esenciales de red...\e[0m"
apt install curl wget git -y

echo -e "\n\e[1;32m------------------------------------------\e[0m"
echo -e "\e[1;32m BLOQUE 0: SISTEMA BASE CONSOLIDADO\e[0m"
echo -e "\e[1;32m El comando 'curl' ahora es estable.\e[0m"
echo -e "\e[1;32m------------------------------------------\e[0m"
echo -e "\e[1;33mPróximo paso: Bloque 1 (Nodejs y Baileys).\e[0m\n"
