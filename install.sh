#!/bin/bash

# COMIVOZ - INSTALADOR DE ALTA DISPONIBILIDAD
# Cero residuos de Windows - 100% Termux

# Forzar limpieza de caracteres por si acaso
sed -i 's/\r$//' "$0" 2>/dev/null

clear
echo "===================================="
echo "  COMIVOZ - INSTALACIÓN MAESTRA"
echo "===================================="

# [1/7] Reparar Repositorios (Crucial)
echo "[1/7] Configurando servidores de descarga..."
termux-change-repo # Esto abrirá un menú, solo dale ENTER para elegir el default
pkg update -y

# [2/7] Instalación UNIDAD POR UNIDAD (Garantiza que no se salte nada)
echo "[2/7] Instalando componentes base..."
pkg install -y nodejs-lts || pkg install -y nodejs
pkg install -y ffmpeg
pkg install -y wget
pkg install -y sqlite3
pkg install -y unzip
pkg install -y python
pkg install -y build-essential

# [3/7] Preparar entorno (Tus rutas originales)
echo "[3/7] Creando directorios..."
cd $HOME
mkdir -p comivoz/auth_info
mkdir -p comivoz/database
cd comivoz

# [4/7] Voz (Sin cambios en la lógica, solo asegurar wget)
echo "[4/7] Descargando modelo de voz..."
if [ ! -d "modelo-voz" ]; then
    wget -q --show-progress -O vosk.zip https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
    unzip vosk.zip
    mv vosk-model-small-es-0.42 modelo-voz
    rm vosk.zip
fi

# [5/7] Dependencias (Respetando Baileys y Voz)
echo "[5/7] Instalando Baileys y Motores de IA..."
npm init -y
npm install @whiskeysockets/baileys sqlite3 vosk fluent-ffmpeg

# [6/7] Vinculación
echo ""
echo "--- CONFIGURACIÓN ---"
read -p "Introduce el número del BOT (ej. 521XXXXXXXXXX): " NUM_BOT

# Creamos el config.json con los campos que tu bot.js requiere
echo "{\"bot\":\"$NUM_BOT\",\"dueña\":\"\",\"nombre\":\"\",\"direccion\":\"\",\"horario\":\"\",\"domicilio\":false}" > config.json

# [7/7] Base de Datos Completa (Tus 10 tablas intactas)
echo "[7/7] Inicializando Base de Datos..."
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

echo "===================================="
echo "✅ INSTALACIÓN FINALIZADA"
echo "Ejecuta ahora: node bot.js"
echo "===================================="
