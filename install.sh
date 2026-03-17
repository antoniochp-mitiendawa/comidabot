#!/bin/bash

# ====================================
# COMIVOZ - INSTALACIÓN COMPLETA
# Un solo comando - TODO INCLUIDO
# Versión CORREGIDA - SIN ERRORES \r
# ====================================

# ELIMINAR CUALQUIER CARÁCTER WINDOWS DE UNA PUTA VEZ
sed -i 's/\r$//' "$0"

clear
echo "===================================="
echo "  COMIVOZ - INSTALACIÓN COMPLETA"
echo "  Un solo comando - TODO INCLUIDO"
echo "===================================="
echo ""

# ====================================
# PASO 1: CONFIGURAR TERMUX
# ====================================
echo "[1/8] Configurando Termux..."
termux-setup-storage
pkg update -y
pkg upgrade -y

# VERIFICAR QUE PKG FUNCIONA
if [ $? -ne 0 ]; then
    echo "❌ Error en pkg update. Reintentando..."
    sleep 2
    pkg update -y
    pkg upgrade -y
fi

# ====================================
# PASO 2: INSTALAR PAQUETES BÁSICOS
# ====================================
echo "[2/8] Instalando paquetes necesarios..."

# LISTA DE PAQUETES A INSTALAR
PAQUETES="nodejs ffmpeg wget"

for PAQUETE in $PAQUETES; do
    echo "   → Instalando $PAQUETE..."
    pkg install -y $PAQUETE
    
    # VERIFICAR QUE SE INSTALÓ
    if [ $? -ne 0 ]; then
        echo "   ⚠️  Reintentando $PAQUETE..."
        sleep 1
        pkg install -y $PAQUETE
    fi
done

# VERIFICAR QUE WGET ESTÉ INSTALADO
if ! command -v wget &> /dev/null; then
    echo "❌ wget no se instaló. Instalando manualmente..."
    pkg install -y wget
fi

# VERIFICAR QUE NODE ESTÉ INSTALADO
if ! command -v node &> /dev/null; then
    echo "❌ nodejs no se instaló. Instalando manualmente..."
    pkg install -y nodejs
fi

# VERIFICAR QUE NPM ESTÉ INSTALADO
if ! command -v npm &> /dev/null; then
    echo "❌ npm no se instaló. Instalando manualmente..."
    pkg install -y nodejs
fi

echo "✅ Paquetes instalados correctamente"

# ====================================
# PASO 3: CREAR ESTRUCTURA DE CARPETAS
# ====================================
echo "[3/8] Creando estructura de carpetas..."
mkdir -p ~/comivoz
cd ~/comivoz || exit 1

mkdir -p database
mkdir -p auth_info
mkdir -p audio_temp
mkdir -p logs

echo "✅ Carpetas creadas en ~/comivoz"

# ====================================
# PASO 4: DESCARGAR MODELO VOSK
# ====================================
echo "[4/8] Descargando modelo de voz Vosk (40MB)..."

cd ~/comivoz || exit 1

# DESCARGAR MODELO
wget -O vosk-model.zip https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip

if [ $? -ne 0 ]; then
    echo "⚠️  Error en descarga. Reintentando..."
    sleep 2
    wget -O vosk-model.zip https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
fi

# VERIFICAR QUE SE DESCARGÓ
if [ ! -f vosk-model.zip ]; then
    echo "❌ No se pudo descargar el modelo. Verifica internet."
    exit 1
fi

echo "   → Descomprimiendo modelo..."
unzip -q vosk-model.zip
rm vosk-model.zip
mv vosk-model-small-es-0.42 modelo-voz

echo "✅ Modelo Vosk instalado en ~/comivoz/modelo-voz"

# ====================================
# PASO 5: INSTALAR DEPENDENCIAS NODE
# ====================================
echo "[5/8] Instalando dependencias de Node.js..."

cd ~/comivoz || exit 1

# CREAR PACKAGE.JSON
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
    "fluent-ffmpeg": "^2.1.2"
  }
}
EOF

# INSTALAR DEPENDENCIAS
echo "   → Instalando @whiskeysockets/baileys..."
npm install @whiskeysockets/baileys

echo "   → Instalando sqlite3..."
npm install sqlite3

echo "   → Instalando vosk..."
npm install vosk

echo "   → Instalando fluent-ffmpeg..."
npm install fluent-ffmpeg

# VERIFICAR QUE TODO SE INSTALÓ
if [ ! -d "node_modules" ]; then
    echo "⚠️  Error en npm install. Reintentando..."
    npm install
fi

echo "✅ Dependencias instaladas correctamente"

# ====================================
# PASO 6: CONFIGURACIÓN INICIAL
# ====================================
echo "[6/8] Configuración inicial del negocio"
echo "----------------------------------------"
echo ""

# LEER DATOS CON VALIDACIÓN
while true; do
    read -p "📱 Número de la dueña (10 dígitos, ej: 5512345678): " NUMERO_DUENA
    if [[ $NUMERO_DUENA =~ ^[0-9]{10}$ ]]; then
        break
    else
        echo "❌ Deben ser 10 dígitos. Intenta de nuevo."
    fi
done

while true; do
    read -p "🤖 Número del bot (10 dígitos, ej: 5512345678): " NUMERO_BOT
    if [[ $NUMERO_BOT =~ ^[0-9]{10}$ ]]; then
        break
    else
        echo "❌ Deben ser 10 dígitos. Intenta de nuevo."
    fi
done

read -p "🏠 Nombre del negocio (ej: Lupita Comidas): " NOMBRE_NEGOCIO
read -p "📍 Dirección (ej: Av. Principal #123): " DIRECCION
read -p "🕒 Horario (ej: 8am a 5pm): " HORARIO

echo ""

# GUARDAR CONFIGURACIÓN
cat > ~/comivoz/config.json << EOF
{
  "duena": "$NUMERO_DUENA",
  "bot": "$NUMERO_BOT",
  "nombre": "$NOMBRE_NEGOCIO",
  "direccion": "$DIRECCION",
  "horario": "$HORARIO",
  "domicilio_activo": false,
  "domicilio_tel": ""
}
EOF

echo "✅ Configuración guardada"

# ====================================
# PASO 7: CREAR BASE DE DATOS
# ====================================
echo "[7/8] Creando base de datos SQLite..."

cd ~/comivoz/database || exit 1

sqlite3 comida.db << 'SQL'
CREATE TABLE IF NOT EXISTS desayunos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  precio INTEGER NOT NULL,
  disponible INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS primer_tiempo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS segundo_tiempo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS tercer_tiempo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS bebida (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS postre (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  disponible INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS precio_comida (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  precio INTEGER NOT NULL,
  fecha TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS domicilio (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  activo INTEGER DEFAULT 0,
  telefono TEXT,
  fecha TEXT DEFAULT CURRENT_TIMESTAMP
);
SQL

if [ $? -eq 0 ]; then
    echo "✅ Base de datos creada correctamente"
else
    echo "❌ Error al crear base de datos"
    exit 1
fi

cd ~/comivoz || exit 1

# ====================================
# PASO 8: CREAR BOT PRINCIPAL
# ====================================
echo "[8/8] Creando bot principal..."

cat > ~/comivoz/bot.js << 'BOT'
// ====================================
// COMIVOZ - BOT PRINCIPAL
// Versión CORREGIDA - SIN ERRORES
// ====================================

const { makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const ffmpeg = require('fluent-ffmpeg');
const vosk = require('vosk');

// ====================================
// CONFIGURACIÓN
// ====================================
let config;
try {
    config = JSON.parse(fs.readFileSync('./config.json'));
} catch (err) {
    console.error('❌ Error leyendo config.json');
    process.exit(1);
}

let db;
try {
    db = new sqlite3.Database('./database/comida.db');
} catch (err) {
    console.error('❌ Error abriendo base de datos');
    process.exit(1);
}

// MODELO VOSK
let model;
try {
    vosk.setLogLevel(-1);
    model = new vosk.Model('./modelo-voz');
} catch (err) {
    console.error('❌ Error cargando modelo Vosk');
    process.exit(1);
}

// ====================================
// FUNCIONES AUXILIARES
// ====================================

function limpiarNumero(numero) {
    if (!numero) return '';
    let limpio = numero.toString().replace(/\D/g, '');
    if (limpio.startsWith('521')) limpio = limpio.substring(3);
    if (limpio.startsWith('52')) limpio = limpio.substring(2);
    return limpio.substring(0, 10);
}

function numeroParaReenvio(numero) {
    let limpio = numero.toString().replace(/\D/g, '');
    if (limpio.startsWith('52')) limpio = limpio.substring(2);
    return '521' + limpio.substring(0, 10);
}

function getSaludo() {
    const hora = new Date().getHours();
    if (hora < 12) return '☀️ BUENOS DÍAS';
    if (hora < 19) return '🌤️ BUENAS TARDES';
    return '🌙 BUENAS NOCHES';
}

function detectarIntencion(texto) {
    const t = texto.toLowerCase();
    
    if (t.includes('sopa') || t.includes('consomé') || t.includes('crema') || t.includes('primer tiempo')) 
        return 'primer_tiempo';
    if (t.includes('arroz') || t.includes('espagueti') || t.includes('segundo tiempo')) 
        return 'segundo_tiempo';
    if (t.includes('guisado') || t.includes('carne') || t.includes('pollo') || t.includes('tercer tiempo')) 
        return 'tercer_tiempo';
    if (t.includes('bebida') || t.includes('agua') || t.includes('refresco')) 
        return 'bebida';
    if (t.includes('postre') || t.includes('dulce')) 
        return 'postre';
    if (t.includes('horario') || t.includes('hora') || t.includes('cierran')) 
        return 'horario';
    if (t.includes('dirección') || t.includes('ubicación') || t.includes('dónde están')) 
        return 'direccion';
    if (t.includes('domicilio') || t.includes('envío') || t.includes('reparten')) 
        return 'domicilio';
        
    return null;
}

// ====================================
// PROCESAR AUDIO
// ====================================

async function procesarAudio(rutaAudio) {
    return new Promise((resolve, reject) => {
        const wavPath = './audio_temp/procesado.wav';
        
        ffmpeg(rutaAudio)
            .audioFrequency(16000)
            .audioChannels(1)
            .audioCodec('pcm_s16le')
            .format('wav')
            .on('end', () => {
                try {
                    const audio = fs.readFileSync(wavPath);
                    const rec = new vosk.Recognizer({ model: model, sampleRate: 16000 });
                    
                    if (rec.acceptWaveform(audio)) {
                        const resultado = JSON.parse(rec.result());
                        resolve(resultado.text);
                    } else {
                        const parcial = JSON.parse(rec.partialResult());
                        resolve(parcial.partial);
                    }
                    
                    rec.free();
                    fs.unlinkSync(wavPath);
                } catch (err) {
                    reject(err);
                }
            })
            .on('error', reject)
            .save(wavPath);
    });
}

// ====================================
// INTERPRETAR INSTRUCCIONES DE LA DUEÑA
// ====================================

async function interpretarInstruccion(texto, remitente) {
    const numeroLimpio = limpiarNumero(remitente);
    if (numeroLimpio !== limpiarNumero(config.duena)) return null;

    texto = texto.toLowerCase();

    // AGREGAR DESAYUNO
    if (texto.includes('desayuno') && (texto.includes('agrega') || texto.includes('tenemos'))) {
        const regex = /([a-záéíóúñ\s]+?)\s+(\d+)/i;
        const match = texto.match(regex);
        if (match) {
            const nombre = match[1].replace('agrega', '').replace('tenemos', '').trim();
            const precio = parseInt(match[2]);
            db.run('INSERT INTO desayunos (nombre, precio) VALUES (?, ?)', [nombre, precio]);
            return `✅ Desayuno agregado: ${nombre} $${precio}`;
        }
    }

    // AGREGAR PRIMER TIEMPO
    if ((texto.includes('primer tiempo') || texto.includes('sopa')) && 
        (texto.includes('agrega') || texto.includes('tenemos'))) {
        const partes = texto.split(',');
        for (const parte of partes) {
            const nombre = parte.replace(/agrega|tenemos|primer tiempo|sopa/gi, '').trim();
            if (nombre && nombre.length > 3) {
                db.run('INSERT INTO primer_tiempo (nombre) VALUES (?)', [nombre]);
            }
        }
        return '✅ Primer tiempo actualizado';
    }

    // AGREGAR SEGUNDO TIEMPO
    if ((texto.includes('segundo tiempo') || texto.includes('arroz')) && 
        (texto.includes('agrega') || texto.includes('tenemos'))) {
        const partes = texto.split(',');
        for (const parte of partes) {
            const nombre = parte.replace(/agrega|tenemos|segundo tiempo|arroz/gi, '').trim();
            if (nombre && nombre.length > 3) {
                db.run('INSERT INTO segundo_tiempo (nombre) VALUES (?)', [nombre]);
            }
        }
        return '✅ Segundo tiempo actualizado';
    }

    // AGREGAR TERCER TIEMPO
    if ((texto.includes('tercer tiempo') || texto.includes('guisado')) && 
        (texto.includes('agrega') || texto.includes('tenemos'))) {
        const partes = texto.split(',');
        for (const parte of partes) {
            const nombre = parte.replace(/agrega|tenemos|tercer tiempo|guisado/gi, '').trim();
            if (nombre && nombre.length > 3) {
                db.run('INSERT INTO tercer_tiempo (nombre) VALUES (?)', [nombre]);
            }
        }
        return '✅ Tercer tiempo actualizado';
    }

    // AGREGAR BEBIDA
    if (texto.includes('bebida') && (texto.includes('agrega') || texto.includes('tenemos'))) {
        const nombre = texto.replace(/agrega|tenemos|bebida/gi, '').trim();
        if (nombre && nombre.length > 3) {
            db.run('INSERT INTO bebida (nombre) VALUES (?)', [nombre]);
            return `✅ Bebida agregada: ${nombre}`;
        }
    }

    // AGREGAR POSTRE
    if (texto.includes('postre') && (texto.includes('agrega') || texto.includes('tenemos'))) {
        const nombre = texto.replace(/agrega|tenemos|postre/gi, '').trim();
        if (nombre && nombre.length > 3) {
            db.run('INSERT INTO postre (nombre) VALUES (?)', [nombre]);
            return `✅ Postre agregado: ${nombre}`;
        }
    }

    // ELIMINAR PLATILLO
    if (texto.includes('elimina') || texto.includes('quita') || texto.includes('se acabó')) {
        const palabras = texto.split(' ');
        let nombreBuscar = '';
        const ignorar = ['elimina', 'quita', 'se', 'acabó', 'ya', 'no'];
        
        for (const p of palabras) {
            if (!ignorar.includes(p) && p.length > 3) {
                nombreBuscar += p + ' ';
            }
        }
        nombreBuscar = nombreBuscar.trim();
        
        if (nombreBuscar) {
            const tablas = ['desayunos', 'primer_tiempo', 'segundo_tiempo', 'tercer_tiempo', 'bebida', 'postre'];
            for (const tabla of tablas) {
                db.run(`UPDATE ${tabla} SET disponible = 0 WHERE nombre LIKE ?`, [`%${nombreBuscar}%`]);
            }
            return `✅ Eliminado: ${nombreBuscar}`;
        }
    }

    // ACTIVAR DOMICILIO
    if (texto.includes('activa domicilio')) {
        const telefono = texto.match(/\d{10}/)?.[0];
        if (telefono) {
            db.run('INSERT INTO domicilio (activo, telefono) VALUES (1, ?)', [telefono]);
            return `✅ Domicilio activado. Reenvíos a: ${telefono}`;
        }
        return '❌ No se encontró número de teléfono';
    }

    // DESACTIVAR DOMICILIO
    if (texto.includes('desactiva domicilio')) {
        db.run('UPDATE domicilio SET activo = 0 WHERE id = (SELECT MAX(id) FROM domicilio)');
        return '✅ Domicilio desactivado';
    }

    // PRECIO COMIDA
    if (texto.includes('precio comida')) {
        const precio = texto.match(/\d+/)?.[0];
        if (precio) {
            db.run('INSERT INTO precio_comida (precio) VALUES (?)', [precio]);
            return `✅ Precio de comida actualizado: $${precio}`;
        }
    }

    return '✅ Instrucción recibida';
}

// ====================================
// GENERAR RESPUESTAS PARA CLIENTES
// ====================================

async function generarMenuCompleto() {
    const saludo = getSaludo();
    const hora = new Date().getHours();
    
    return new Promise((resolve) => {
        // ANTES DE 12: SOLO DESAYUNOS
        if (hora < 12) {
            db.all('SELECT nombre, precio FROM desayunos WHERE disponible = 1', [], (err, rows) => {
                if (!rows || rows.length === 0) {
                    resolve(`${saludo}\n\nHoy no hay desayunos registrados.\n\n🕒 ${config.horario}\n📍 ${config.direccion}`);
                    return;
                }
                
                let resp = `${saludo}\n\n`;
                resp += `🍳 *DESAYUNOS*\n`;
                rows.forEach(r => {
                    resp += `• ${r.nombre} $${r.precio}\n`;
                });
                resp += `\n🕒 ${config.horario}\n📍 ${config.direccion}`;
                resolve(resp);
            });
        } 
        // DESPUÉS DE 12: COMIDA COMPLETA
        else {
            db.get('SELECT precio FROM precio_comida ORDER BY id DESC LIMIT 1', [], (err, precioRow) => {
                let resp = `${saludo}\n\n`;
                
                if (precioRow) {
                    resp += `Comida corrida *$${precioRow.precio}*\n\n`;
                }
                
                db.all('SELECT nombre FROM primer_tiempo WHERE disponible = 1', [], (e1, r1) => {
                    if (r1 && r1.length > 0) {
                        resp += `🥣 *PRIMER TIEMPO*\n`;
                        r1.forEach(p => resp += `• ${p.nombre}\n`);
                        resp += `\n`;
                    }
                    
                    db.all('SELECT nombre FROM segundo_tiempo WHERE disponible = 1', [], (e2, r2) => {
                        if (r2 && r2.length > 0) {
                            resp += `🍚 *SEGUNDO TIEMPO*\n`;
                            r2.forEach(p => resp += `• ${p.nombre}\n`);
                            resp += `\n`;
                        }
                        
                        db.all('SELECT nombre FROM tercer_tiempo WHERE disponible = 1', [], (e3, r3) => {
                            if (r3 && r3.length > 0) {
                                resp += `🍖 *TERCER TIEMPO*\n`;
                                r3.forEach(p => resp += `• ${p.nombre}\n`);
                                resp += `\n`;
                            }
                            
                            db.all('SELECT nombre FROM bebida WHERE disponible = 1', [], (e4, r4) => {
                                if (r4 && r4.length > 0) {
                                    resp += `🥤 *BEBIDA*\n`;
                                    r4.forEach(p => resp += `• ${p.nombre}\n`);
                                    resp += `\n`;
                                }
                                
                                db.all('SELECT nombre FROM postre WHERE disponible = 1', [], (e5, r5) => {
                                    if (r5 && r5.length > 0) {
                                        resp += `🍨 *POSTRE*\n`;
                                        r5.forEach(p => resp += `• ${p.nombre}\n`);
                                        resp += `\n`;
                                    }
                                    
                                    db.get('SELECT activo FROM domicilio WHERE activo = 1 ORDER BY id DESC LIMIT 1', [], (e6, domRow) => {
                                        resp += `🕒 ${config.horario}\n📍 ${config.direccion}`;
                                        
                                        if (domRow && domRow.activo === 1) {
                                            resp += `\n\n🚚 ¿Necesitas domicilio? Responde *SÍ*`;
                                        }
                                        
                                        resolve(resp);
                                    });
                                });
                            });
                        });
                    });
                });
            });
        }
    });
}

async function generarRespuestaEspecifica(tipo) {
    return new Promise((resolve) => {
        switch(tipo) {
            case 'primer_tiempo':
                db.all('SELECT nombre FROM primer_tiempo WHERE disponible = 1', [], (e, r) => {
                    if (!r || r.length === 0) return resolve('🥣 Hoy no hay sopas registradas');
                    let resp = '🥣 *PRIMER TIEMPO*\n';
                    r.forEach(p => resp += `• ${p.nombre}\n`);
                    resolve(resp);
                });
                break;
                
            case 'segundo_tiempo':
                db.all('SELECT nombre FROM segundo_tiempo WHERE disponible = 1', [], (e, r) => {
                    if (!r || r.length === 0) return resolve('🍚 Hoy no hay arroz/espagueti registrados');
                    let resp = '🍚 *SEGUNDO TIEMPO*\n';
                    r.forEach(p => resp += `• ${p.nombre}\n`);
                    resolve(resp);
                });
                break;
                
            case 'tercer_tiempo':
                db.all('SELECT nombre FROM tercer_tiempo WHERE disponible = 1', [], (e, r) => {
                    if (!r || r.length === 0) return resolve('🍖 Hoy no hay guisados registrados');
                    let resp = '🍖 *TERCER TIEMPO*\n';
                    r.forEach(p => resp += `• ${p.nombre}\n`);
                    resolve(resp);
                });
                break;
                
            case 'bebida':
                db.all('SELECT nombre FROM bebida WHERE disponible = 1', [], (e, r) => {
                    if (!r || r.length === 0) return resolve('🥤 Hoy no hay bebidas registradas');
                    let resp = '🥤 *BEBIDA*\n';
                    r.forEach(p => resp += `• ${p.nombre}\n`);
                    resolve(resp);
                });
                break;
                
            case 'postre':
                db.all('SELECT nombre FROM postre WHERE disponible = 1', [], (e, r) => {
                    if (!r || r.length === 0) return resolve('🍨 Hoy no hay postres registrados');
                    let resp = '🍨 *POSTRE*\n';
                    r.forEach(p => resp += `• ${p.nombre}\n`);
                    resolve(resp);
                });
                break;
                
            case 'horario':
                resolve(`🕒 *HORARIO*\n${config.horario}\n\n📍 ${config.direccion}`);
                break;
                
            case 'direccion':
                resolve(`📍 *DIRECCIÓN*\n${config.direccion}\n\n🕒 ${config.horario}`);
                break;
                
            case 'domicilio':
                db.get('SELECT activo FROM domicilio WHERE activo = 1 ORDER BY id DESC LIMIT 1', [], (e, r) => {
                    if (r && r.activo === 1) {
                        resolve('🚚 *DOMICILIO*\nSí tenemos servicio.\n\n¿Te interesa? Responde *SÍ*');
                    } else {
                        resolve('🚚 Por el momento no tenemos servicio a domicilio.');
                    }
                });
                break;
                
            default:
                resolve(null);
        }
    });
}

// ====================================
// MANEJAR DOMICILIO
// ====================================

async function manejarDomicilio(numeroCliente, sock) {
    return new Promise((resolve) => {
        db.get('SELECT telefono FROM domicilio WHERE activo = 1 ORDER BY id DESC LIMIT 1', [], (err, row) => {
            if (!row || !row.telefono) {
                resolve();
                return;
            }
            
            const numeroMostrar = limpiarNumero(numeroCliente);
            const numeroReenvio = numeroParaReenvio(row.telefono);
            const fecha = new Date();
            const hora = `${fecha.getHours().toString().padStart(2,'0')}:${fecha.getMinutes().toString().padStart(2,'0')}`;
            
            const mensaje = `🚚 *SOLICITUD DE DOMICILIO*\n━━━━━━━━━━━━━━━━━━━━━\n\n👤 Cliente: *${numeroMostrar}*\n🕒 Hora: ${hora}\n━━━━━━━━━━━━━━━━━━━━━\n✅ Solicitó ser contactado\n\n📞 *Llama ahora:*\n${numeroMostrar}`;
            
            try {
                sock.sendMessage(`${numeroReenvio}@s.whatsapp.net`, { text: mensaje });
            } catch (err) {
                console.error('Error enviando mensaje de domicilio:', err);
            }
            
            resolve();
        });
    });
}

// ====================================
// CONEXIÓN WHATSAPP
// ====================================

async function conectarWhatsApp() {
    console.log('🔄 Conectando a WhatsApp...');
    
    let sock;
    try {
        const { state, saveCreds } = await useMultiFileAuthState('./auth_info');
        
        sock = makeWASocket({
            auth: state,
            browser: ['ComiVoz', 'Safari', '1.0.0']
        });

        sock.ev.on('creds.update', saveCreds);

        sock.ev.on('connection.update', (update) => {
            const { connection, lastDisconnect } = update;
            
            if (connection === 'open') {
                console.log('✅ WhatsApp CONECTADO');
                console.log(`📱 Dueña: ${config.duena}`);
                console.log(`🤖 Bot listo para recibir mensajes`);
            }
            
            if (connection === 'close') {
                const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== 401;
                console.log('❌ Conexión cerrada' + (shouldReconnect ? ', reconectando...' : ''));
                if (shouldReconnect) {
                    setTimeout(conectarWhatsApp, 5000);
                }
            }
        });

        sock.ev.on('messages.upsert', async ({ messages }) => {
            const m = messages[0];
            if (!m || !m.message) return;
            
            const remitente = m.key.remoteJid;
            if (remitente.endsWith('@g.us')) return;
            
            const numeroLimpio = limpiarNumero(remitente);
            const esDueña = (numeroLimpio === limpiarNumero(config.duena));
            
            // ====================================
            // AUDIOS DE LA DUEÑA
            // ====================================
            if (m.message.audioMessage && esDueña) {
                console.log('🎤 Audio recibido de la dueña');
                
                try {
                    const buffer = await m.message.audioMessage.download();
                    const audioPath = `./audio_temp/${Date.now()}.ogg`;
                    fs.writeFileSync(audioPath, buffer);
                    
                    const texto = await procesarAudio(audioPath);
                    console.log(`📝 Transcripción: ${texto}`);
                    
                    const respuesta = await interpretarInstruccion(texto, remitente);
                    if (respuesta) {
                        await sock.sendMessage(remitente, { text: respuesta });
                    }
                    
                    fs.unlinkSync(audioPath);
                } catch (err) {
                    console.error('Error procesando audio:', err);
                    await sock.sendMessage(remitente, { text: '❌ Error procesando audio' });
                }
                return;
            }
            
            // ====================================
            // TEXTOS DE CLIENTES
            // ====================================
            if (m.message.conversation) {
                const texto = m.message.conversation;
                console.log(`💬 Cliente ${numeroLimpio}: ${texto}`);
                
                // RESPUESTA A DOMICILIO
                if (texto.toLowerCase() === 'sí' || texto.toLowerCase() === 'si') {
                    db.get('SELECT activo FROM domicilio WHERE activo = 1 ORDER BY id DESC LIMIT 1', [], async (err, row) => {
                        if (row && row.activo === 1) {
                            await sock.sendMessage(remitente, { text: '👍 Gracias. En unos minutos te llamaremos.' });
                            await manejarDomicilio(remitente, sock);
                        }
                    });
                    return;
                }
                
                // PREGUNTA GENERAL
                if (texto.toLowerCase().includes('qué hay') || 
                    texto.toLowerCase().includes('menú') || 
                    texto.toLowerCase().includes('comida')) {
                    const menu = await generarMenuCompleto();
                    await sock.sendMessage(remitente, { text: menu });
                    return;
                }
                
                // PREGUNTA ESPECÍFICA
                const intencion = detectarIntencion(texto);
                if (intencion) {
                    const respuesta = await generarRespuestaEspecifica(intencion);
                    if (respuesta) {
                        await sock.sendMessage(remitente, { text: respuesta });
                    }
                }
            }
        });

    } catch (err) {
        console.error('Error en conexión WhatsApp:', err);
        setTimeout(conectarWhatsApp, 5000);
    }

    return sock;
}

// ====================================
// INICIAR BOT
// ====================================

console.log('====================================');
console.log('  COMIVOZ - INICIANDO');
console.log('====================================');

conectarWhatsApp().catch(err => {
    console.error('Error fatal:', err);
    process.exit(1);
});
BOT

echo ""
echo "===================================="
echo "✅ INSTALACIÓN COMPLETADA"
echo "===================================="
echo ""
echo "📱 Dueña: $NUMERO_DUENA"
echo "🤖 Bot: $NUMERO_BOT"
echo "🏠 $NOMBRE_NEGOCIO"
echo ""
echo "⚠️  IMPORTANTE:"
echo "1. Ve a WhatsApp > Dispositivos vinculados"
echo "2. Elige 'Vincular con número de teléfono'"
echo "3. Presiona ENTER para generar código"
echo ""

read -p "Presiona ENTER para generar código de emparejamiento: "

# ====================================
# GENERAR CÓDIGO DE EMPAREJAMIENTO
# ====================================
echo ""
echo "Generando código de emparejamiento..."

cd ~/comivoz || exit 1

node -e "
const { makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');

async function generarCodigo() {
    try {
        const { state } = await useMultiFileAuthState('./auth_info');
        const sock = makeWASocket({ auth: state });
        
        setTimeout(() => {
            console.log('\\n🔑 CÓDIGO DE EMPAREJAMIENTO:');
            console.log('====================================');
            console.log(state.creds.registrationId);
            console.log('====================================');
            console.log('\\nCopia este código y pégalo en WhatsApp');
            console.log('\\nDespués de vincular, el bot iniciará automáticamente');
            process.exit(0);
        }, 3000);
    } catch (err) {
        console.error('Error generando código:', err);
        process.exit(1);
    }
}

generarCodigo();
"

echo ""
echo "===================================="
echo "🚀 INICIANDO COMIVOZ..."
echo "===================================="
echo ""

cd ~/comivoz || exit 1
node bot.js
