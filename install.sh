#!/bin/bash

# ====================================
# COMIVOZ - INSTALACIÓN MAESTRA
# Corregida para compatibilidad total
# ====================================

# 1. Autolimpieza de formato (Crucial para evitar errores \r)
if [[ $(type -p sed) ]]; then
    sed -i 's/\r$//' "$0" 2>/dev/null
fi

clear
echo "===================================="
echo "  COMIVOZ - INSTALACIÓN COMPLETA"
echo "  Optimizada y sin errores"
echo "===================================="

# 2. Configuración de Repositorios y Actualización
echo "[1/7] Configurando el entorno..."
pkg update -y && pkg upgrade -y

# 3. Instalación de Dependencias de Sistema
echo "[2/7] Instalando herramientas base..."
pkg install -y nodejs ffmpeg wget sqlite3 unzip

# 4. Estructura de Archivos
echo "[3/7] Preparando directorios..."
mkdir -p comivoz/auth_info
cd comivoz

# 5. Descarga de Modelo de Voz (Vosk)
echo "[4/7] Descargando modelo de voz (esto puede tardar)..."
if [ ! -d "modelo-voz" ]; then
    wget -q --show-progress -O vosk.zip https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
    unzip -q vosk.zip
    rm vosk.zip
    mv vosk-model-small-es-0.42 modelo-voz
fi

# 6. Inicialización de Node.js y Dependencias
echo "[5/7] Instalando dependencias del bot..."
npm init -y
npm install @whiskeysockets/baileys sqlite3 vosk fluent-ffmpeg

# 7. Configuración del Negocio
echo ""
echo "--- CONFIGURACIÓN DEL NEGOCIO ---"
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
  "horario": "$HORARIO"
}
EOF

# 8. Creación de Base de Datos
echo "[7/7] Inicializando base de datos..."
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
echo "✅ INSTALACIÓN FINALIZADA CON ÉXITO"
echo "===================================="
echo ""
echo "Para iniciar el bot, usa: node bot.js"
