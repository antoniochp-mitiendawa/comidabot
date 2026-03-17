#!/bin/bash

# ====================================
# COMIVOZ - INSTALACIÓN PROFESIONAL
# ====================================

# Limpieza inmediata de caracteres basura
# [cite: 31]
clear
echo "===================================="
echo "  COMIVOZ - INSTALACIÓN INICIADA"
echo "===================================="

# 1. Preparación del Entorno (Fuerza Bruta)
# Instalamos wget primero para asegurar las descargas
echo "[1/7] Actualizando sistema..."
yes | pkg update
yes | pkg upgrade
pkg install -y wget nodejs ffmpeg sqlite3 unzip ncurses-utils

# 2. Estructura de archivos
# [cite: 31]
echo "[2/7] Creando carpetas..."
mkdir -p ~/comivoz/auth_info
cd ~/comivoz

# 3. Descarga del Modelo de Voz (Vosk)
# [cite: 31]
echo "[3/7] Instalando modelo de voz..."
if [ ! -d "modelo-voz" ]; then
    wget -O vosk.zip https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
    unzip vosk.zip && rm vosk.zip
    mv vosk-model-small-es-0.42 modelo-voz
fi

# 4. Dependencias Node.js
# [cite: 31]
echo "[4/7] Instalando dependencias de IA..."
npm init -y
npm install @whiskeysockets/baileys sqlite3 vosk fluent-ffmpeg

# 5. Configuración Interactiva
# [cite: 32]
echo ""
echo "--- DATOS DEL NEGOCIO ---"
printf "Número de la dueña: "; read DUEÑA
printf "Nombre del negocio: "; read NOMBRE
printf "Dirección: "; read DIR
printf "Horario: "; read HORARIO

cat > config.json << EOF
{
  "dueña": "$DUEÑA",
  "nombre": "$NOMBRE",
  "direccion": "$DIR",
  "horario": "$HORARIO"
}
EOF

# 6. Base de Datos
# [cite: 32, 33, 34, 35, 36, 37, 38]
echo "[6/7] Configurando base de datos..."
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
echo "✅ INSTALACIÓN COMPLETA"
echo "===================================="
