#!/bin/bash

# === SCRIPT DE INSTALACIÓN PARA COMIDABOT ===
# Ejecutar en Termux después de clonar el repositorio

echo "======================================"
echo "   COMIDABOT - INSTALACIÓN COMPLETA"
echo "======================================"
echo ""

# Paso 1: Actualizar Termux
echo "[1/8] Actualizando Termux..."
pkg update -y && pkg upgrade -y
echo "✅ Termux actualizado"
echo ""

# Paso 2: Instalar herramientas base
echo "[2/8] Instalando herramientas base (git, nodejs, python, ffmpeg)..."
pkg install git nodejs-lts python ffmpeg sox opus-tools tmux -y
echo "✅ Herramientas base instaladas"
echo ""

# Paso 3: Instalar pip y vosk (transcripción de voz local)
echo "[3/8] Instalando Vosk para reconocimiento de voz offline..."
pip install vosk
echo "✅ Vosk instalado"
echo ""

# Paso 4: Crear directorio para el modelo de voz
echo "[4/8] Descargando modelo de español para Vosk..."
mkdir -p ~/comidabot/model
cd ~/comidabot/model
if [ ! -f "vosk-model-small-es-0.42.zip" ]; then
    wget https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
    unzip vosk-model-small-es-0.42.zip
    mv vosk-model-small-es-0.42/* .
    rmdir vosk-model-small-es-0.42
    rm vosk-model-small-es-0.42.zip
fi
echo "✅ Modelo de español descargado"
cd ~/comidabot
echo ""

# Paso 5: Inicializar proyecto Node.js
echo "[5/8] Inicializando proyecto Node.js..."
npm init -y
echo "✅ Proyecto inicializado"
echo ""

# Paso 6: Instalar dependencias de Node.js
echo "[6/8] Instalando dependencias de Node.js (Baileys, SQLite, etc.)..."
npm install @whiskeysockets/baileys qrcode-terminal pino sqlite3 wav @mapbox/node-pre-gyp
echo "✅ Dependencias instaladas"
echo ""

# Paso 7: Crear directorios necesarios
echo "[7/8] Creando directorios para sesión y base de datos..."
mkdir -p auth_info
mkdir -p db
echo "✅ Directorios creados"
echo ""

# Paso 8: Dar permisos de ejecución al bot
echo "[8/8] Dando permisos de ejecución..."
chmod +x bot.js
echo "✅ Permisos asignados"
echo ""

echo "======================================"
echo "   INSTALACIÓN COMPLETA"
echo "======================================"
echo ""
echo "Para iniciar el bot, ejecuta:"
echo "  node bot.js"
echo ""
echo "Asegúrate de tener el archivo bot.js en el mismo directorio"
echo ""
