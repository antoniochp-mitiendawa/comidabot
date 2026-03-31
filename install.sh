#!/data/data/com.termux/files/usr/bin/bash

echo "---------------------------------------------------------"
echo "REPARANDO E INSTALANDO COMIDABOT - MODO COMPILACIÓN"
echo "---------------------------------------------------------"

# FASE 1: Herramientas de Construcción (Crítico para sqlite3)
pkg update -y && pkg upgrade -y
pkg install -y nodejs git python python-pip build-essential binutils wget proot-distro
pip install setuptools # Necesario para Python 3.13

# FASE 2: IA LOCAL
if [ ! -d "$HOME/.proot-distro/installed-rootfs/ubuntu" ]; then
    proot-distro install ubuntu
fi
proot-distro login ubuntu -- bash -c "curl -fsSL https://ollama.com/install.sh | sh"
proot-distro login ubuntu -- bash -c "ollama serve > /dev/null 2>&1 & sleep 8 && ollama pull llama3.2:1b"

# FASE 3: LIBRERÍAS DE NODE CON COMPILACIÓN LOCAL
cd $HOME/comidabot
npm install -g node-gyp # Herramienta para compilar sqlite3 en el cel
npm install --build-from-source # Fuerza a que se cree la base de datos correctamente

# FASE 4: CONFIGURACIÓN DE NÚMEROS
echo "---------------------------------------------------------"
read -p "Introduce el número del BOT (ej. 521XXXXXXXXXX): " BOT_PHONE
read -p "Introduce el número del DUEÑO (ej. 521XXXXXXXXXX): " OWNER_PHONE

echo "OWNER_RAW_NUMBER=$OWNER_PHONE" > .env
echo "BOT_NUMBER=$BOT_PHONE" >> .env

echo "---------------------------------------------------------"
echo "TODO INSTALADO. Iniciando vinculación..."
node index.js
