#!/data/data/com.termux/files/usr/bin/bash

# =============================================
# INSTALADOR DE COMIDABOT PARA TERMUX
# Versión: 1.1 (Corregida)
# =============================================

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
MAGENTA='\033[0;35m'
CIAN='\033[0;36m'
BLANCO='\033[1;37m'
NC='\033[0m'

# Función para mostrar mensajes
mensaje() {
    echo -e "${AZUL}[COMIDABOT]${NC} $1"
}

mensaje_ok() {
    echo -e "${VERDE}[✓]${NC} $1"
}

mensaje_error() {
    echo -e "${ROJO}[✗]${NC} $1"
}

mensaje_advertencia() {
    echo -e "${AMARILLO}[!]${NC} $1"
}

mensaje_titulo() {
    echo -e "${MAGENTA}=========================================${NC}"
    echo -e "${CIAN}$1${NC}"
    echo -e "${MAGENTA}=========================================${NC}"
}

# Función para verificar si el paso anterior fue exitoso
verificar_paso() {
    if [ $? -eq 0 ]; then
        mensaje_ok "$1"
    else
        mensaje_error "$2"
        echo -e "${ROJO}La instalación se detuvo en el paso: $3${NC}"
        exit 1
    fi
}

# Función para esperar confirmación del usuario
esperar_usuario() {
    echo ""
    echo -e "${AMARILLO}Presiona ENTER para continuar...${NC}"
    read
}

# =============================================
# INICIO DE LA INSTALACIÓN
# =============================================
clear
mensaje_titulo "COMIDABOT - INSTALACIÓN EN TERMUX"
echo ""
echo -e "${BLANCO}Este instalador configurará todo lo necesario para:${NC}"
echo -e "  ${VERDE}•${NC} WhatsApp Bot con Baileys"
echo -e "  ${VERDE}•${NC} Whisper.cpp para reconocimiento de voz"
echo -e "  ${VERDE}•${NC} Base de datos SQLite"
echo -e "  ${VERDE}•${NC} Sistema de menús diarios"
echo -e "  ${VERDE}•${NC} Respuestas automáticas con spintax"
echo ""
echo -e "${AMARILLO}⚠️  IMPORTANTE:${NC}"
echo -e "  • Asegúrate de tener buena conexión a internet"
echo -e "  • No cierres Termux durante la instalación"
echo -e "  • El proceso puede tomar 10-20 minutos"
echo ""
esperar_usuario

# =============================================
# PASO 1: Actualizar Termux
# =============================================
clear
mensaje_titulo "PASO 1/12 - ACTUALIZANDO TERMUX"
mensaje "Actualizando repositorios y paquetes básicos..."
# Configuración para evitar prompts de archivos de configuración
export DEBIAN_FRONTEND=noninteractive
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold"
verificar_paso "Termux actualizado correctamente" "Error al actualizar Termux" "Paso 1 - Actualización"

# =============================================
# PASO 2: Instalar dependencias base
# =============================================
clear
mensaje_titulo "PASO 2/12 - INSTALANDO DEPENDENCIAS BASE"
mensaje "Instalando paquetes esenciales..."

pkg install -y \
    nodejs \
    python \
    git \
    wget \
    curl \
    build-essential \
    cmake \
    ffmpeg \
    imagemagick \
    openssl \
    sqlite \
    nano

verificar_paso "Dependencias base instaladas" "Error al instalar dependencias base" "Paso 2 - Dependencias base"

# =============================================
# PASO 3: Crear directorio del proyecto
# =============================================
clear
mensaje_titulo "PASO 3/12 - CREANDO DIRECTORIO DEL PROYECTO"

cd ~
if [ -d "comidabot" ]; then
    mensaje_advertencia "El directorio comidabot ya existe. ¿Deseas eliminarlo? (s/n)"
    read -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm -rf comidabot
        mensaje "Directorio eliminado"
    else
        mensaje_error "No se puede continuar con un directorio existente"
        exit 1
    fi
fi

mkdir -p ~/comidabot
cd ~/comidabot
verificar_paso "Directorio creado en ~/comidabot" "Error al crear directorio" "Paso 3 - Directorio"

# =============================================
# PASO 4: Instalar Whisper.cpp
# =============================================
clear
mensaje_titulo "PASO 4/12 - INSTALANDO WHISPER.CPP"

mensaje "Clonando repositorio de Whisper.cpp..."
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

mensaje "Compilando Whisper.cpp (esto puede tomar varios minutos)..."
make -j4
verificar_paso "Compilación completada" "Error al compilar Whisper.cpp" "Paso 4 - Compilación"

mensaje "Descargando modelo TINY..."
bash ./models/download-ggml-model.sh tiny
verificar_paso "Modelo TINY descargado" "Error al descargar modelo TINY" "Paso 4 - Descarga modelo"

cd ~/comidabot

# =============================================
# PASO 5: Inicializar proyecto Node.js
# =============================================
clear
mensaje_titulo "PASO 5/12 - INICIALIZANDO PROYECTO NODE.JS"

cat > package.json << 'EOF'
{
  "name": "comidabot",
  "version": "1.0.0",
  "description": "Bot de WhatsApp para comidas corridas",
  "main": "bot.js",
  "type": "module",
  "scripts": {
    "start": "node bot.js"
  },
  "keywords": ["whatsapp", "bot", "comidas"],
  "author": "",
  "license": "ISC"
}
EOF
verificar_paso "package.json configurado" "Error al crear package.json" "Paso 5 - npm init"

# =============================================
# PASO 6: Instalar dependencias de Node.js
# =============================================
clear
mensaje_titulo "PASO 6/12 - INSTALANDO DEPENDENCIAS NODE.JS"

npm install @whiskeysockets/baileys pino sqlite3 node-fetch fluent-ffmpeg qrcode-terminal audio-decode
verificar_paso "Dependencias npm instaladas" "Error al instalar dependencias npm" "Paso 6 - npm install"

# =============================================
# PASO 7: Crear estructura de directorios
# =============================================
mkdir -p src/baileys src/whisper src/database src/spintax src/utils auth_info logs audios
verificar_paso "Estructura de directorios creada" "Error al crear directorios" "Paso 7 - Directorios"

# =============================================
# PASO 8: Crear base de datos SQLite
# =============================================
clear
mensaje_titulo "PASO 8/12 - CREANDO BASE DE DATOS"

cat > crear_bd.sql << 'EOF'
CREATE TABLE IF NOT EXISTS negocio (id INTEGER PRIMARY KEY DEFAULT 1, nombre TEXT DEFAULT 'Mi Restaurante', telefono TEXT, slogan TEXT, direccion TEXT);
CREATE TABLE IF NOT EXISTS horarios (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT, dia_inicio TEXT, dia_fin TEXT, hora_apertura TEXT, hora_cierre TEXT, activo BOOLEAN DEFAULT 1);
CREATE TABLE IF NOT EXISTS domicilio (id INTEGER PRIMARY KEY AUTOINCREMENT, activo BOOLEAN DEFAULT 0, telefono_contacto TEXT, horario TEXT);
CREATE TABLE IF NOT EXISTS avisos_pedidos (id INTEGER PRIMARY KEY AUTOINCREMENT, numero TEXT UNIQUE, nombre TEXT, activo BOOLEAN DEFAULT 1, ultimo_aviso DATETIME, orden INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS menu_desayunos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha DATE, platillo TEXT, precio INTEGER, incluye TEXT DEFAULT 'Café o té + fruta', disponible BOOLEAN DEFAULT 1);
CREATE TABLE IF NOT EXISTS menu_comida_tiempos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha DATE, tiempo INTEGER, nombre_tiempo TEXT, opciones TEXT, incluye TEXT, precio_total INTEGER, disponible BOOLEAN DEFAULT 1);
CREATE TABLE IF NOT EXISTS autorizados (id INTEGER PRIMARY KEY AUTOINCREMENT, numero TEXT UNIQUE, rol TEXT DEFAULT 'dueño', activo BOOLEAN DEFAULT 1);
CREATE TABLE IF NOT EXISTS spintax (id INTEGER PRIMARY KEY AUTOINCREMENT, categoria TEXT, variante TEXT);
CREATE TABLE IF NOT EXISTS conversaciones (id INTEGER PRIMARY KEY AUTOINCREMENT, numero_cliente TEXT, fecha DATE, ultimo_mensaje DATETIME, variaciones_usadas TEXT);
CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, tipo TEXT, mensaje TEXT);

INSERT OR IGNORE INTO spintax (categoria, variante) VALUES 
('saludo', '{☀️|🌅|🙌|🌞|🌤️} {BUENOS DÍAS|BUEN DÍA|Muy buenos días|QUÉ TAL}'),
('saludo_tarde', '{🌤️|☀️|🌞} {BUENAS TARDES|BUENA TARDE|QUÉ TAL}'),
('saludo_noche', '{🌙|✨|🌆} {BUENAS NOCHES|BUENA NOCHE}'),
('icono_platillo', '{🥚|🍳|🌮|🍽️|🥘}'),
('icono_dinero', '{💰|💵|💲|🪙|💸}'),
('bebida', '{☕ Café|🧋 Café|🫖 Té|🍵 Té}'),
('fruta', '{🍉 fruta|🍍 fruta|🍈 fruta|🍊 fruta|🍓 fruta}'),
('incluye', '{Incluye:|Todo incluye:|Acompañado de:}'),
('espera', '{un momentito|espera|solo un segundo|ahora sigo|continuamos}'),
('confirmacion_si', '{Sí|Está bien|Ok|Perfecto|Dale|Sale}'),
('confirmacion_no', '{No|Nel|No gracias|Mejor no}');
EOF

sqlite3 comidabot.db < crear_bd.sql
verificar_paso "Base de datos creada" "Error en la DB" "Paso 8"

# =============================================
# PASO 9: Configuración y Números
# =============================================
clear
mensaje_titulo "PASO 9/10 - CONFIGURACIÓN DE NÚMEROS"

echo -e "${BLANCO}Ingresa el número del BOT (ej: 5215512345678):${NC}"
read NUMERO_BOT
echo -e "${BLANCO}Ingresa el número del DUEÑO:${NC}"
read NUMERO_DUENO

cat > config.json << EOF
{
    "numero_bot": "$NUMERO_BOT",
    "numero_dueño": "$NUMERO_DUENO",
    "whisper_path": "./whisper.cpp/main",
    "whisper_model": "./whisper.cpp/models/ggml-tiny.bin",
    "delay_min": 5,
    "delay_max": 10,
    "typing_min": 3,
    "typing_max": 7,
    "db_path": "./comidabot.db"
}
EOF

sqlite3 comidabot.db "INSERT OR IGNORE INTO autorizados (numero, rol) VALUES ('$NUMERO_DUENO', 'dueño');"

# =============================================
# PASO 10: Scripts Finales y Emparejamiento
# =============================================
cat > emparejar.js << 'EOF'
import makeWASocket from '@whiskeysockets/baileys';
import { useMultiFileAuthState } from '@whiskeysockets/baileys';
import pino from 'pino';
import fs from 'fs';

const config = JSON.parse(fs.readFileSync('./config.json', 'utf8'));

async function emparejar() {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info');
    const sock = makeWASocket({
        auth: state,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false,
    });

    if (!sock.authState.creds.registered) {
        setTimeout(async () => {
            let code = await sock.requestPairingCode(config.numero_bot);
            console.log(`\n\x1b[32m🔑 CÓDIGO DE EMPAREJAMIENTO: \x1b[1m${code}\x1b[0m\n`);
        }, 2000);
    }

    sock.ev.on('creds.update', saveCreds);
    sock.ev.on('connection.update', (update) => {
        if (update.connection === 'open') {
            console.log('\x1b[32m✅ CONECTADO EXITOSAMENTE\x1b[0m');
            process.exit(0);
        }
    });
}
emparejar();
EOF

cat > bot.js << 'EOF'
import makeWASocket from '@whiskeysockets/baileys';
import { useMultiFileAuthState } from '@whiskeysockets/baileys';
import pino from 'pino';
import fs from 'fs';
import sqlite3 from 'sqlite3';

const config = JSON.parse(fs.readFileSync('./config.json', 'utf8'));
const db = new sqlite3.Database(config.db_path);

async function startBot() {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info');
    const sock = makeWASocket({ auth: state, logger: pino({ level: 'silent' }) });
    sock.ev.on('creds.update', saveCreds);
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;
        console.log(`Mensaje de ${m.key.remoteJid}: ${m.message.conversation || ''}`);
        // Lógica de respuesta simplificada para test
        await sock.sendMessage(m.key.remoteJid, { text: '🤖 Bot Activo' });
    });
    console.log('🤖 Bot en línea...');
}
startBot();
EOF

mensaje_ok "Instalación completada."
mensaje "Para emparejar ejecuta: node emparejar.js"
mensaje "Para iniciar el bot ejecuta: npm start"
