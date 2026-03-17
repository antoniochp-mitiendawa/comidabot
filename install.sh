#!/data/data/com.termux/files/usr/bin/bash

# =============================================
# INSTALADOR DE COMIDABOT PARA TERMUX
# Versión: 1.1 (Corrección de Dependencias)
# =============================================

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
MAGENTA='\033[0;35m'
CIAN='\033[0;36m'
BLANCO='\033[1;37m'
NC='\033[0m' # Sin color

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
echo -e "  ${VERDE}•${NC} WhatsApp Bot con Baileys [cite: 3]"
echo -e "  ${VERDE}•${NC} Whisper.cpp para reconocimiento de voz [cite: 3]"
echo -e "  ${VERDE}•${NC} Base de datos SQLite [cite: 3]"
echo -e "  ${VERDE}•${NC} Sistema de menús diarios [cite: 3]"
echo -e "  ${VERDE}•${NC} Respuestas automáticas con spintax [cite: 3]"
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
# Forzamos la no-interactividad para evitar bloqueos en el upgrade
export DEBIAN_FRONTEND=noninteractive
pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confold" [cite: 4]
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
    nano [cite: 5]

verificar_paso "Dependencias base instaladas" "Error al instalar dependencias base" "Paso 2 - Dependencias base"

# =============================================
# PASO 3: Crear directorio del proyecto
# =============================================
clear
mensaje_titulo "PASO 3/12 - CREANDO DIRECTORIO DEL PROYECTO"

cd ~
if [ -d "comidabot" ]; then [cite: 6]
    rm -rf comidabot [cite: 7]
    mensaje "Directorio anterior eliminado para instalación limpia"
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
cd whisper.cpp [cite: 8]

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
[cite: 9]
verificar_paso "package.json configurado" "Error al crear package.json" "Paso 5 - npm init"

# =============================================
# PASO 6: Instalar dependencias de Node.js
# =============================================
clear
mensaje_titulo "PASO 6/12 - INSTALANDO DEPENDENCIAS NODE.JS"

mensaje "Instalando paquetes npm (Solución para Termux)..."

# Instalamos las dependencias evitando scripts de compilación nativa que fallan
npm install @whiskeysockets/baileys pino node-fetch fluent-ffmpeg qrcode-terminal audio-decode --ignore-scripts [cite: 10]

# Instalamos sqlite3 forzando que no intente compilar si no es necesario o usamos la precompilada
npm install sqlite3 --save --build-from-source=false

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
CREATE TABLE IF NOT EXISTS negocio (id INTEGER PRIMARY KEY DEFAULT 1, nombre TEXT DEFAULT 'Mi Restaurante', telefono TEXT, slogan TEXT, direccion TEXT); [cite: 11]
CREATE TABLE IF NOT EXISTS horarios (id INTEGER PRIMARY KEY AUTOINCREMENT, tipo TEXT, dia_inicio TEXT, dia_fin TEXT, hora_apertura TEXT, hora_cierre TEXT, activo BOOLEAN DEFAULT 1); [cite: 12]
CREATE TABLE IF NOT EXISTS domicilio (id INTEGER PRIMARY KEY AUTOINCREMENT, activo BOOLEAN DEFAULT 0, telefono_contacto TEXT, horario TEXT); [cite: 13]
CREATE TABLE IF NOT EXISTS avisos_pedidos (id INTEGER PRIMARY KEY AUTOINCREMENT, numero TEXT UNIQUE, nombre TEXT, activo BOOLEAN DEFAULT 1, ultimo_aviso DATETIME, orden INTEGER DEFAULT 0); [cite: 14]
CREATE TABLE IF NOT EXISTS menu_desayunos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha DATE, platillo TEXT, precio INTEGER, incluye TEXT DEFAULT 'Café o té + fruta', disponible BOOLEAN DEFAULT 1); [cite: 15]
CREATE TABLE IF NOT EXISTS menu_comida_tiempos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha DATE, tiempo INTEGER, nombre_tiempo TEXT, opciones TEXT, incluye TEXT, precio_total INTEGER, disponible BOOLEAN DEFAULT 1); [cite: 16]
CREATE TABLE IF NOT EXISTS autorizados (id INTEGER PRIMARY KEY AUTOINCREMENT, numero TEXT UNIQUE, rol TEXT DEFAULT 'dueño', activo BOOLEAN DEFAULT 1); [cite: 17]
CREATE TABLE IF NOT EXISTS spintax (id INTEGER PRIMARY KEY AUTOINCREMENT, categoria TEXT, variante TEXT); [cite: 18]
CREATE TABLE IF NOT EXISTS conversaciones (id INTEGER PRIMARY KEY AUTOINCREMENT, numero_cliente TEXT, fecha DATE, ultimo_mensaje DATETIME, variaciones_usadas TEXT); [cite: 19]
CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, tipo TEXT, mensaje TEXT); [cite: 20]

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
('confirmacion_no', '{No|Nel|No gracias|Mejor no}'); [cite: 21]
EOF

sqlite3 comidabot.db < crear_bd.sql
verificar_paso "Base de datos creada" "Error en la DB" "Paso 8"

# =============================================
# PASO 10: Configuración de Números
# =============================================
clear
mensaje_titulo "PASO 10/12 - CONFIGURACIÓN DE NÚMEROS" [cite: 22]

echo -e "${BLANCO}Ingresa el número del BOT (ej: 5215512345678):${NC}"
read NUMERO_BOT [cite: 23]
echo -e "${BLANCO}Ingresa el número del DUEÑO:${NC}"
read NUMERO_DUENO [cite: 24]

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

sqlite3 comidabot.db "INSERT OR IGNORE INTO autorizados (numero, rol) VALUES ('$NUMERO_DUENO', 'dueño');" [cite: 25]

# =============================================
# PASO 11: Script de Emparejamiento
# =============================================
cat > emparejar.js << 'EOF'
import makeWASocket from '@whiskeysockets/baileys'; [cite: 26]
import { useMultiFileAuthState } from '@whiskeysockets/baileys'; [cite: 27]
import pino from 'pino';
import fs from 'fs';

const config = JSON.parse(fs.readFileSync('./config.json', 'utf8')); [cite: 28]

async function emparejar() {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info'); [cite: 29]
    const sock = makeWASocket({
        auth: state,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false, [cite: 30]
    });

    if (!sock.authState.creds.registered) {
        setTimeout(async () => {
            let code = await sock.requestPairingCode(config.numero_bot); [cite: 31]
            console.log(`\n🔑 CÓDIGO DE EMPAREJAMIENTO: ${code}\n`); [cite: 32]
        }, 2000);
    }

    sock.ev.on('creds.update', saveCreds); [cite: 33]
    sock.ev.on('connection.update', (update) => {
        if (update.connection === 'open') { [cite: 34]
            console.log('✅ CONECTADO EXITOSAMENTE');
            process.exit(0);
        } [cite: 35]
    });
}
emparejar(); [cite: 36]
EOF

# =============================================
# PASO 12: Script Principal
# =============================================
cat > bot.js << 'EOF'
import makeWASocket from '@whiskeysockets/baileys'; [cite: 37]
import { useMultiFileAuthState } from '@whiskeysockets/baileys'; [cite: 38]
import pino from 'pino';
import fs from 'fs';
import sqlite3 from 'sqlite3'; [cite: 39]
import { exec } from 'child_process'; [cite: 40]

const config = JSON.parse(fs.readFileSync('./config.json', 'utf8')); [cite: 41]
const db = new sqlite3.Database(config.db_path); [cite: 42]

async function startBot() {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info'); [cite: 43]
    const sock = makeWASocket({ auth: state, logger: pino({ level: 'silent' }) }); [cite: 44]
    
    sock.ev.on('creds.update', saveCreds); [cite: 45]
    
    sock.ev.on('messages.upsert', async ({ messages }) => { [cite: 46]
        const m = messages[0];
        if (!m.message || m.key.fromMe) return; [cite: 47]
        
        const from = m.key.remoteJid;
        const text = m.message.conversation || m.message.extendedTextMessage?.text || ''; [cite: 48]
        const isAudio = m.message.audioMessage ? true : false; [cite: 49]
        
        db.get('SELECT * FROM autorizados WHERE numero = ?', [from.split('@')[0]], async (err, autorizado) => { [cite: 50]
            if (autorizado && isAudio) {
                await sock.sendMessage(from, { text: '🎤 Procesando audio del dueño...' });
            } else if (!isAudio) {
                await sock.sendMessage(from, { text: '🤖 Bot funcionando correctamente' });
            }
        });
    });
    console.log('🤖 Bot en línea...');
}
startBot(); [cite: 51]
EOF

mensaje_ok "Instalación completada satisfactoriamente."
