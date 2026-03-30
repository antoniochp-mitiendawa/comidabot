#!/usr/bin/env node

// ============================================
// COMIDABOT - Bot de WhatsApp para Comida Corrida
// Versión: 1.0.2 (con wake lock y pairing code corregido)
// ============================================

const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = require('@whiskeysockets/baileys');
const { Boom } = require('@hapi/boom');
const P = require('pino');
const fs = require('fs');
const path = require('path');
const Database = require('yskj-sqlite-android');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

// ============================================
// CONFIGURACIÓN INICIAL
// ============================================

let adminID = null;
let modoCliente = false;
let horarioCierre = null;
let horarioDesayunos = { inicio: "07:00", fin: "12:00" };
let horarioComidas = { inicio: "12:00", fin: "18:00" };
let precioFijoDesayunos = null;
let precioFijoComida = null;

const AUTH_DIR = './auth_info';
const DB_DIR = './db';
const TEMP_AUDIO_DIR = './temp_audio';
const WHISPER_CLI = 'whisper-cli';
const WHISPER_MODEL = '/data/data/com.termux/files/home/whisper.cpp/models/ggml-base.bin';

let db;

// ============================================
// BASE DE DATOS
// ============================================

function initDatabase() {
    if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR);
    
    db = new Database(path.join(DB_DIR, 'comidabot.db'));
    
    db.exec(`CREATE TABLE IF NOT EXISTS config (
        clave TEXT PRIMARY KEY,
        valor TEXT
    )`);
    
    db.exec(`CREATE TABLE IF NOT EXISTS desayunos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto TEXT,
        precio TEXT,
        incluye TEXT,
        fecha TEXT
    )`);
    
    db.exec(`CREATE TABLE IF NOT EXISTS comida_primer_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcion TEXT,
        fecha TEXT
    )`);
    
    db.exec(`CREATE TABLE IF NOT EXISTS comida_segundo_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcion TEXT,
        fecha TEXT
    )`);
    
    db.exec(`CREATE TABLE IF NOT EXISTS comida_tercer_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcion TEXT,
        fecha TEXT
    )`);
    
    db.exec(`CREATE TABLE IF NOT EXISTS acompanamientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT,
        descripcion TEXT,
        fecha TEXT
    )`);
    
    const adminRow = db.prepare("SELECT valor FROM config WHERE clave = 'admin_id'").get();
    if (adminRow) adminID = adminRow.valor;
    
    const cierreRow = db.prepare("SELECT valor FROM config WHERE clave = 'horario_cierre'").get();
    if (cierreRow) horarioCierre = cierreRow.valor;
    
    const desayunosRow = db.prepare("SELECT valor FROM config WHERE clave = 'horario_desayunos'").get();
    if (desayunosRow) horarioDesayunos = JSON.parse(desayunosRow.valor);
    
    const comidasRow = db.prepare("SELECT valor FROM config WHERE clave = 'horario_comidas'").get();
    if (comidasRow) horarioComidas = JSON.parse(comidasRow.valor);
    
    const precioDesRow = db.prepare("SELECT valor FROM config WHERE clave = 'precio_fijo_desayunos'").get();
    if (precioDesRow) precioFijoDesayunos = precioDesRow.valor;
    
    const precioComRow = db.prepare("SELECT valor FROM config WHERE clave = 'precio_fijo_comida'").get();
    if (precioComRow) precioFijoComida = precioComRow.valor;
    
    console.log('📦 Base de datos inicializada');
}

function guardarConfig(clave, valor) {
    const stmt = db.prepare("INSERT OR REPLACE INTO config (clave, valor) VALUES (?, ?)");
    stmt.run(clave, valor);
}

function limpiarDia() {
    const hoy = new Date().toISOString().split('T')[0];
    db.prepare("DELETE FROM desayunos WHERE fecha != ?").run(hoy);
    db.prepare("DELETE FROM comida_primer_tiempo WHERE fecha != ?").run(hoy);
    db.prepare("DELETE FROM comida_segundo_tiempo WHERE fecha != ?").run(hoy);
    db.prepare("DELETE FROM comida_tercer_tiempo WHERE fecha != ?").run(hoy);
    db.prepare("DELETE FROM acompanamientos WHERE fecha != ?").run(hoy);
    console.log('🧹 Base de datos limpiada para nuevo día');
}

// ============================================
// TRANSCRIPCIÓN DE VOZ
// ============================================

async function transcribirAudio(bufferAudio) {
    const tempOpus = path.join(TEMP_AUDIO_DIR, `audio_${Date.now()}.opus`);
    const tempWav = path.join(TEMP_AUDIO_DIR, `audio_${Date.now()}.wav`);
    const tempTxt = tempWav + '.txt';
    
    if (!fs.existsSync(TEMP_AUDIO_DIR)) fs.mkdirSync(TEMP_AUDIO_DIR);
    fs.writeFileSync(tempOpus, bufferAudio);
    await execAsync(`ffmpeg -i ${tempOpus} -ar 16000 -ac 1 -c:a pcm_s16le ${tempWav} -y`);
    
    try {
        await execAsync(`${WHISPER_CLI} -m ${WHISPER_MODEL} -f ${tempWav} -otxt -l es`);
        let texto = '';
        if (fs.existsSync(tempTxt)) {
            texto = fs.readFileSync(tempTxt, 'utf8').trim();
        }
        fs.unlinkSync(tempOpus);
        fs.unlinkSync(tempWav);
        if (fs.existsSync(tempTxt)) fs.unlinkSync(tempTxt);
        return texto.toLowerCase();
    } catch (error) {
        console.error('Error en transcripción:', error);
        if (fs.existsSync(tempOpus)) fs.unlinkSync(tempOpus);
        if (fs.existsSync(tempWav)) fs.unlinkSync(tempWav);
        if (fs.existsSync(tempTxt)) fs.unlinkSync(tempTxt);
        return '';
    }
}

// ============================================
// INTERPRETACIÓN SEMÁNTICA
// ============================================

function interpretarInstruccion(texto) {
    const instruccion = { tipo: null, datos: {} };
    
    if (texto.includes('agrega') || texto.includes('registra') || texto.includes('tenemos')) {
        instruccion.tipo = 'agregar';
        if (texto.includes('desayuno')) instruccion.datos.categoria = 'desayunos';
        if (texto.includes('comida') || texto.includes('primer tiempo') || texto.includes('segundo tiempo') || texto.includes('tercer tiempo')) {
            instruccion.datos.categoria = 'comida';
        }
    }
    
    if (texto.includes('elimina') || texto.includes('borra') || texto.includes('ya no')) {
        instruccion.tipo = 'eliminar';
    }
    
    if (texto.includes('cambia') || texto.includes('actualiza')) {
        instruccion.tipo = 'actualizar';
    }
    
    if (texto.includes('configura') || texto.includes('establece')) {
        instruccion.tipo = 'configurar';
    }
    
    if (texto.includes('reinicia') && (texto.includes('base') || texto.includes('datos'))) {
        instruccion.tipo = 'reiniciar';
    }
    
    if (texto.includes('activar modo cliente')) instruccion.tipo = 'modo_cliente_on';
    if (texto.includes('desactivar modo cliente')) instruccion.tipo = 'modo_cliente_off';
    if (texto.includes('en qué modo')) instruccion.tipo = 'consultar_modo';
    
    return instruccion;
}

function interpretarPreguntaCliente(texto) {
    if (texto.includes('desayuno')) return 'desayunos';
    if (texto.includes('comida') || texto.includes('corrida')) return 'comida';
    if (texto.includes('ubicación') || texto.includes('dirección') || texto.includes('dónde están')) return 'ubicacion';
    if (texto.includes('horario')) return 'horario';
    return 'general';
}

// ============================================
// RESPUESTAS AL CLIENTE
// ============================================

function obtenerHoraActual() {
    const ahora = new Date();
    return ahora.toTimeString().slice(0,5);
}

function estaEnHorario(horario) {
    const ahora = obtenerHoraActual();
    return ahora >= horario.inicio && ahora <= horario.fin;
}

async function responderDesayunos(sock, to) {
    const stmt = db.prepare("SELECT producto, precio, incluye FROM desayunos ORDER BY id");
    const desayunos = stmt.all();
    
    if (desayunos.length === 0) {
        await sock.sendMessage(to, { text: "🍳 Por el momento no tenemos desayunos registrados para hoy." });
        return;
    }
    
    let mensaje = "🍳 *DESAYUNOS*\n\n";
    for (const d of desayunos) {
        mensaje += `• ${d.producto}`;
        if (d.precio) mensaje += ` - $${d.precio}`;
        mensaje += `\n`;
    }
    if (desayunos[0]?.incluye) mensaje += `\n*Incluye:* ${desayunos[0].incluye}`;
    await sock.sendMessage(to, { text: mensaje });
}

async function responderComidaCompleta(sock, to) {
    const primerStmt = db.prepare("SELECT opcion FROM comida_primer_tiempo ORDER BY id");
    const segundoStmt = db.prepare("SELECT opcion FROM comida_segundo_tiempo ORDER BY id");
    const tercerStmt = db.prepare("SELECT opcion FROM comida_tercer_tiempo ORDER BY id");
    const acompanamientosStmt = db.prepare("SELECT tipo, descripcion FROM acompanamientos ORDER BY id");
    
    const primerTiempo = primerStmt.all().map(r => r.opcion);
    const segundoTiempo = segundoStmt.all().map(r => r.opcion);
    const tercerTiempo = tercerStmt.all().map(r => r.opcion);
    const acompanamientos = acompanamientosStmt.all();
    
    if (primerTiempo.length > 0) {
        let msg = "🍽️ *PRIMER TIEMPO* (Sopa/Consomé)\n";
        primerTiempo.forEach(op => { msg += `• ${op}\n`; });
        await sock.sendMessage(to, { text: msg });
        await new Promise(r => setTimeout(r, 2000));
    }
    
    if (segundoTiempo.length > 0) {
        let msg = "🍚 *SEGUNDO TIEMPO* (Arroz/Pasta)\n";
        segundoTiempo.forEach(op => { msg += `• ${op}\n`; });
        await sock.sendMessage(to, { text: msg });
        await new Promise(r => setTimeout(r, 2000));
    }
    
    if (tercerTiempo.length > 0) {
        const mitad = Math.ceil(tercerTiempo.length / 2);
        const parte1 = tercerTiempo.slice(0, mitad);
        const parte2 = tercerTiempo.slice(mitad);
        
        let msg1 = "🍗 *TERCER TIEMPO* (Guisados)\n";
        parte1.forEach(op => { msg1 += `• ${op}\n`; });
        await sock.sendMessage(to, { text: msg1 });
        await new Promise(r => setTimeout(r, 2000));
        
        if (parte2.length > 0) {
            let msg2 = "🍗 *TERCER TIEMPO (Continuación)*\n";
            parte2.forEach(op => { msg2 += `• ${op}\n`; });
            await sock.sendMessage(to, { text: msg2 });
            await new Promise(r => setTimeout(r, 2000));
        }
    }
    
    if (acompanamientos.length > 0) {
        let msg = "🥤 *INCLUYE*\n";
        acompanamientos.forEach(a => { msg += `• ${a.descripcion}\n`; });
        await sock.sendMessage(to, { text: msg });
        await new Promise(r => setTimeout(r, 1500));
    }
    
    if (precioFijoComida) {
        await sock.sendMessage(to, { text: `💰 *Precio único: $${precioFijoComida} MXN*` });
    }
}

// ============================================
// PROCESAMIENTO DE MENSAJES
// ============================================

async function procesarMensaje(sock, msg, sender, messageText, esVoz) {
    const esAdmin = (adminID === sender);
    
    if (esAdmin && !modoCliente) {
        if (esVoz) {
            const instruccion = interpretarInstruccion(messageText);
            switch (instruccion.tipo) {
                case 'agregar':
                    await sock.sendMessage(sender, { text: "✅ Información registrada. Procesando..." });
                    break;
                case 'eliminar':
                    await sock.sendMessage(sender, { text: "✅ Eliminado" });
                    break;
                case 'actualizar':
                    await sock.sendMessage(sender, { text: "✅ Actualizado" });
                    break;
                case 'configurar':
                    await sock.sendMessage(sender, { text: "✅ Configurado" });
                    break;
                case 'reiniciar':
                    limpiarDia();
                    await sock.sendMessage(sender, { text: "✅ Base de datos reiniciada" });
                    break;
                case 'modo_cliente_on':
                    modoCliente = true;
                    await sock.sendMessage(sender, { text: "🧪 Modo cliente activado" });
                    break;
                case 'modo_cliente_off':
                    modoCliente = false;
                    await sock.sendMessage(sender, { text: "✅ Modo cliente desactivado" });
                    break;
                case 'consultar_modo':
                    const estado = modoCliente ? "🧪 Modo cliente" : "🔧 Modo admin";
                    await sock.sendMessage(sender, { text: `Estás en: ${estado}` });
                    break;
                default:
                    await sock.sendMessage(sender, { text: "✅ Instrucción recibida" });
            }
        }
        return;
    }
    
    const pregunta = interpretarPreguntaCliente(messageText);
    await sock.sendPresenceUpdate('composing', sender);
    await new Promise(r => setTimeout(r, 1500));
    
    switch (pregunta) {
        case 'desayunos':
            if (!estaEnHorario(horarioDesayunos)) {
                if (estaEnHorario(horarioComidas)) {
                    await sock.sendMessage(sender, { text: "🙏 Discúlpamos, los desayunos ya terminaron. ¿Quieres la información de las comidas?" });
                } else {
                    await sock.sendMessage(sender, { text: `🌙 Los desayunos son de ${horarioDesayunos.inicio} a ${horarioDesayunos.fin}` });
                }
            } else {
                await responderDesayunos(sock, sender);
            }
            break;
        case 'comida':
            if (!estaEnHorario(horarioComidas)) {
                await sock.sendMessage(sender, { text: `🍽️ Las comidas empiezan a las ${horarioComidas.inicio}. Escríbenos cerca de ese horario` });
            } else {
                await responderComidaCompleta(sock, sender);
            }
            break;
        case 'ubicacion':
            await sock.sendMessage(sender, { text: "📍 Calle Juárez #123, Colonia Centro" });
            break;
        case 'horario':
            await sock.sendMessage(sender, { text: `🕐 Desayunos: ${horarioDesayunos.inicio}-${horarioDesayunos.fin}\n🍽️ Comidas: ${horarioComidas.inicio}-${horarioComidas.fin}` });
            break;
        default:
            await sock.sendMessage(sender, { text: "🍽️ Pregúntame por: desayunos, comidas, horarios o ubicación" });
    }
}

// ============================================
// INICIO DEL BOT
// ============================================

async function startBot() {
    console.log("🚀 Iniciando ComidaBot...");
    initDatabase();
    
    const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
    const { version } = await fetchLatestBaileysVersion();
    
    const sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
        logger: P({ level: 'silent' }),
        browser: ['Windows', 'Chrome', '114.0.5735.198'],
        defaultQueryTimeoutMs: undefined,
        keepAliveIntervalMs: 30000
    });
    
    sock.ev.on('creds.update', saveCreds);
    
    let pairingRequested = false;
    
    sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect } = update;
        
        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) startBot();
        } else if (connection === 'open') {
            console.log("✅ Bot conectado exitosamente");
            
            // CORRECCIÓN: Esperar a que la conexión esté abierta para pedir pairing code
            if (!state.creds.registered && !pairingRequested) {
                pairingRequested = true;
                
                // Delay de 2 segundos para asegurar estabilidad
                await new Promise(resolve => setTimeout(resolve, 2000));
                
                const readline = require('readline');
                const rl = readline.createInterface({
                    input: process.stdin,
                    output: process.stdout
                });
                
                rl.question("📱 Ingresa el número del BOT que quieres vincular (ej. 5215551234567): ", async (numero) => {
                    console.log("📟 Solicitando código de emparejamiento...");
                    try {
                        const code = await sock.requestPairingCode(numero);
                        console.log(`🔑 Código de emparejamiento: ${code}`);
                        console.log("📲 Abre WhatsApp, ve a Dispositivos vinculados y escribe este código.");
                        console.log("⏳ Esperando vinculación...");
                    } catch (error) {
                        console.error("❌ Error al solicitar código:", error.message);
                        console.log("🔄 Reintentando en 5 segundos...");
                        setTimeout(() => {
                            pairingRequested = false;
                        }, 5000);
                    }
                    rl.close();
                });
            }
            
            // Configuración del dueño si no existe
            if (!adminID) {
                console.log("\n==========================================");
                console.log("⚙️ CONFIGURACIÓN INICIAL");
                console.log("==========================================");
                
                const readline = require('readline');
                const rl = readline.createInterface({
                    input: process.stdin,
                    output: process.stdout
                });
                
                rl.question("📱 Ingresa el número del DUEÑO (admin): ", async (numero) => {
                    const numeroCompleto = `${numero}@s.whatsapp.net`;
                    await sock.sendMessage(numeroCompleto, { text: "🔐 Responde para confirmar que eres el administrador" });
                    console.log("⏳ Esperando respuesta...");
                    rl.close();
                });
            } else {
                console.log(`👑 Dueño: ${adminID}`);
                console.log("🎧 Esperando instrucciones...");
            }
        }
    });
    
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const msg = messages[0];
        if (!msg.message || msg.key.fromMe) return;
        
        const sender = msg.key.remoteJid;
        if (sender.endsWith('@g.us')) return;
        
        let messageText = '';
        let esVoz = false;
        
        if (msg.message.conversation) {
            messageText = msg.message.conversation;
        } else if (msg.message.extendedTextMessage?.text) {
            messageText = msg.message.extendedTextMessage.text;
        } else if (msg.message.audioMessage) {
            esVoz = true;
            const stream = await sock.downloadMediaMessage(msg);
            const chunks = [];
            for await (const chunk of stream) chunks.push(chunk);
            const buffer = Buffer.concat(chunks);
            messageText = await transcribirAudio(buffer);
            console.log(`🎤 Transcripción: ${messageText}`);
        } else {
            return;
        }
        
        console.log(`📩 De: ${sender.split('@')[0]} | "${messageText}"`);
        
        if (adminID === null && sender !== 'status@broadcast') {
            adminID = sender;
            guardarConfig('admin_id', adminID);
            console.log(`✅ Dueño verificado: ${adminID}`);
            await sock.sendMessage(sender, { text: "✅ Eres el administrador. DAME INSTRUCCIONES POR VOZ." });
            return;
        }
        
        await procesarMensaje(sock, msg, sender, messageText, esVoz);
    });
}

startBot().catch(err => console.error("❌ Error fatal:", err));
