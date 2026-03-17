#!/bin/bash

# ====================================
# COMIVOZ - INSTALACIÓN COMPLETA
# Un solo comando - TODO INCLUIDO
# ====================================

# Limpiar caracteres Windows si existen
sed -i 's/\r$//' "$0" 2>/dev/null

clear
echo "===================================="
echo "  COMIVOZ - INSTALACIÓN COMPLETA"
echo "  Un solo comando - TODO INCLUIDO"
echo "===================================="
echo ""

echo "[1/7] Configurando Termux..."
termux-setup-storage
pkg update -y
pkg upgrade -y

echo "[2/7] Instalando lo necesario..."
pkg install -y nodejs ffmpeg wget sqlite3 unzip

echo "[3/7] Creando carpetas..."
mkdir -p comivoz/auth_info
mkdir -p comivoz/database
cd comivoz

echo "[4/7] Descargando modelo de voz..."
if [ ! -d "modelo-voz" ]; then
    wget -O vosk.zip https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
    unzip vosk.zip
    rm vosk.zip
    mv vosk-model-small-es-0.42 modelo-voz
fi

echo "[5/7] Instalando dependencias..."
npm init -y
npm install @whiskeysockets/baileys sqlite3 vosk fluent-ffmpeg

echo "[6/7] Configuración inicial"
echo "------------------------"
read -p "Número de la dueña (10 dígitos): " DUEÑA
read -p "Número del bot (10 dígitos): " BOT
read -p "Nombre del negocio: " NOMBRE
read -p "Dirección: " DIR
read -p "Horario: " HORARIO

cat > config.json << EOF
{
  "dueña": "$DUEÑA",
  "bot": "$BOT",
  "nombre": "$NOMBRE",
  "direccion": "$DIR",
  "horario": "$HORARIO",
  "domicilio": false
}
EOF

echo "[7/7] Creando base de datos..."
sqlite3 comida.db << SQL
CREATE TABLE IF NOT EXISTS desayunos (id INTEGER PRIMARY KEY, nombre TEXT, precio INTEGER, disponible INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS primer_tiempo (id INTEGER PRIMARY KEY, nombre TEXT, disponible INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS segundo_tiempo (id INTEGER PRIMARY KEY, nombre TEXT, disponible INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS tercer_tiempo (id INTEGER PRIMARY KEY, nombre TEXT, disponible INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS bebida (id INTEGER PRIMARY KEY, nombre TEXT, disponible INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS postre (id INTEGER PRIMARY KEY, nombre TEXT, disponible INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS precio_comida (id INTEGER PRIMARY KEY, precio INTEGER);
CREATE TABLE IF NOT EXISTS domicilio (id INTEGER PRIMARY KEY, activo INTEGER DEFAULT 0, telefono TEXT);
SQL

echo ""
echo "===================================="
echo "✅ TODO LISTO"
echo "===================================="
echo ""
echo "Para iniciar el bot: node bot.js"
