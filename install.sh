#!/bin/bash

# ====================================
# COMIVOZ - INSTALADOR AUTOMÁTICO
# Un solo comando, todo listo
# ====================================

clear
echo "===================================="
echo "  COMIVOZ - INSTALACIÓN AUTOMÁTICA"
echo "  Un solo comando, todo listo"
echo "===================================="
echo ""

# PASO 1: Actualizar Termux
echo "[1/9] Actualizando Termux..."
pkg update -y && pkg upgrade -y

# PASO 2: Instalar paquetes necesarios
echo "[2/9] Instalando paquetes necesarios..."
pkg install -y nodejs ffmpeg git sqlite wget curl

# PASO 3: Crear carpetas del proyecto
echo "[3/9] Creando estructura de carpetas..."
mkdir -p comivoz
cd comivoz
mkdir -p database
mkdir -p models
mkdir -p logs

# PASO 4: Descargar modelo Vosk (español - 40MB)
echo "[4/9] Descargando modelo de voz Vosk español (40MB)..."
cd models
wget https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
unzip vosk-model-small-es-0.42.zip
rm vosk-model-small-es-0.42.zip
mv vosk-model-small-es-0.42 vosk-model
cd ..

# PASO 5: Crear package.json e instalar dependencias
echo "[5/9] Instalando dependencias de Node.js..."
cat > package.json << 'EOF'
{
  "name": "comivoz",
  "version": "1.0.0",
  "description": "Sistema de menú por voz para comida corrida",
  "main": "bot.js",
  "dependencies": {
    "@whiskeysockets/baileys": "^6.5.0",
    "sqlite3": "^5.1.6",
    "vosk": "^0.3.45",
    "fluent-ffmpeg": "^2.1.2",
    "qrcode-terminal": "^0.12.0"
  }
}
EOF

npm install

# PASO 6: Preguntar datos al usuario
echo "[6/9] Configuración inicial (solo una vez)"
echo "----------------------------------------"
echo ""
read -p "📱 Número de la dueña (quien mandará audios, ej: 5512345678): " NUMERO_DUENA
read -p "🤖 Número del bot (el que emparejaremos, ej: 5512345678): " NUMERO_BOT
read -p "🏠 Nombre del negocio (ej: Lupita Comidas): " NOMBRE_NEGOCIO
read -p "📍 Dirección (ej: Av. Principal #123): " DIRECCION
read -p "🕒 Horario (ej: 8am a 5pm): " HORARIO
echo ""

# PASO 7: Guardar configuración
echo "[7/9] Guardando configuración..."
cat > config.json << EOF
{
  "numero_duena": "$NUMERO_DUENA",
  "numero_bot": "$NUMERO_BOT",
  "nombre_negocio": "$NOMBRE_NEGOCIO",
  "direccion": "$DIRECCION",
  "horario": "$HORARIO",
  "domicilio_activo": false,
  "telefono_domicilio": ""
}
EOF

# PASO 8: Crear base de datos SQLite
echo "[8/9] Creando base de datos..."
cat > database/schema.sql << 'EOF'
CREATE TABLE IF NOT EXISTS desayunos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  precio INTEGER NOT NULL,
  disponible BOOLEAN DEFAULT 1,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS primer_tiempo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible BOOLEAN DEFAULT 1,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS segundo_tiempo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible BOOLEAN DEFAULT 1,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tercer_tiempo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible BOOLEAN DEFAULT 1,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bebida (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible BOOLEAN DEFAULT 1,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS postre (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible BOOLEAN DEFAULT 1,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS precio_comida (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  precio INTEGER NOT NULL,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS domicilio_config (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  activo BOOLEAN DEFAULT 0,
  telefono_reenvio TEXT,
  fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS solicitudes_domicilio (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero_cliente TEXT NOT NULL,
  fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP,
  estado TEXT DEFAULT 'pendiente'
);

CREATE TABLE IF NOT EXISTS sinonimos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  palabra TEXT NOT NULL,
  categoria TEXT NOT NULL,
  prioridad INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS emojis_categoria (
  categoria TEXT PRIMARY KEY,
  emoji_principal TEXT NOT NULL,
  emojis_secundarios TEXT
);

INSERT OR IGNORE INTO emojis_categoria (categoria, emoji_principal) VALUES
('desayuno', '🍳'),
('primer_tiempo', '🥣'),
('segundo_tiempo', '🍚'),
('tercer_tiempo', '🍖'),
('bebida', '🥤'),
('postre', '🍨'),
('horario', '🕒'),
('direccion', '📍'),
('precio', '💰'),
('domicilio', '🚚');
EOF

sqlite3 database/comivoz.db < database/schema.sql

# PASO 9: Descargar bot.js desde GitHub
echo "[9/9] Descargando bot principal..."
curl -o bot.js https://raw.githubusercontent.com/TU-USUARIO/comivoz/main/bot.js

echo ""
echo "===================================="
echo "✅ INSTALACIÓN COMPLETADA"
echo "===================================="
echo ""
echo "📱 Número de la dueña: $NUMERO_DUENA"
echo "🤖 Número del bot: $NUMERO_BOT"
echo "🏠 Negocio: $NOMBRE_NEGOCIO"
echo ""
echo "⚠️  IMPORTANTE:"
echo "En tu WhatsApp ve a:"
echo "Menú > Dispositivos vinculados > Vincular un dispositivo"
echo ""
echo "Presiona ENTER para generar el código de emparejamiento"
read

echo "Generando código de emparejamiento..."
node -e "
const { makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
async function main() {
  const { state, saveCreds } = await useMultiFileAuthState('auth_info');
  const sock = makeWASocket({ auth: state });
  sock.ev.on('creds.update', saveCreds);
  setTimeout(() => {
    console.log('\\n🔑 CÓDIGO DE EMPAREJAMIENTO:');
    console.log('====================================');
    console.log(sock.authState.creds.registrationId);
    console.log('====================================');
    console.log('\\nCopia este código y pégalo en WhatsApp');
    process.exit(0);
  }, 5000);
}
main();
"

echo ""
echo "===================================="
echo "🚀 INICIANDO COMIVOZ..."
echo "===================================="
node bot.js
