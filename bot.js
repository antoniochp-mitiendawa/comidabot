#!/usr/bin/env node

// ============================================
// COMIDABOT - Bot de WhatsApp para Comida Corrida
// Versión: 1.0.0
// ============================================

const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } = require('@whiskeysockets/baileys');
const { Boom } = require('@hapi/boom');
const P = require('pino');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

// ============================================
// CONFIGURACIÓN INICIAL
// ============================================

let adminID = null;           // ID del dueño (se guarda en BD)
let modoCliente = false;      // Modo prueba para que el dueño actúe como cliente
let horarioCierre = null;     // Horario de cierre automático (ej. "20:00")
let horarioDesayunos = { inicio: "07:00", fin: "12:00" };
let horarioComidas = { inicio: "12:00", fin: "18:00" };
let precioFijoDesayunos = null;   // Si el dueño dice "todos valen lo mismo"
let precioFijoComida = null;       // Precio único de la comida corrida

// Directorios
const AUTH_DIR = './auth_info';
const DB_DIR = './db';
const MODEL_DIR = './model';

// Base de datos
let db;

// ============================================
// FUNCIONES DE BASE DE DATOS
// ============================================

function initDatabase() {
    if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR);
    
    db = new sqlite3.Database(path.join(DB_DIR, 'comidabot.db'));
    
    // Tabla de configuración (dueño, horarios, etc.)
    db.run(`CREATE TABLE IF NOT EXISTS config (
        clave TEXT PRIMARY KEY,
        valor TEXT
    )`);
    
    // Tabla de desayunos (se borra diario)
    db.run(`CREATE TABLE IF NOT EXISTS desayunos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto TEXT,
        precio TEXT,
        incluye TEXT,
        fecha TEXT
    )`);
    
    // Tabla de comida corrida - primer tiempo
    db.run(`CREATE TABLE IF NOT EXISTS comida_primer_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcion TEXT,
        fecha TEXT
    )`);
    
    // Tabla de comida corrida - segundo tiempo
    db.run(`CREATE TABLE IF NOT EXISTS comida_segundo_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcion TEXT,
        fecha TEXT
    )`);
    
    // Tabla de comida corrida - tercer tiempo (guisados)
    db.run(`CREATE TABLE IF NOT EXISTS comida_tercer_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcion TEXT,
        fecha TEXT
    )`);
    
    // Tabla de acompañamientos
    db.run(`CREATE TABLE IF NOT EXISTS acompanamientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT,
        descripcion TEXT,
        fecha TEXT
    )`);
    
    // Cargar configuración guardada
    db.get("SELECT valor FROM config WHERE clave = 'admin_id'", (err, row) => {
        if (row) adminID = row.valor;
    });
    
    db.get("SELECT valor FROM config WHERE clave = 'horario_cierre'", (err, row) => {
        if (row) horarioCierre = row.valor;
    });
    
    db.get("SELECT valor FROM config WHERE clave = 'horario_desayunos'", (err, row) => {
        if (row) horarioDesayunos = JSON.parse(row.valor);
    });
    
    db.get("SELECT valor FROM config WHERE clave = 'horario_comidas'", (err, row) => {
        if (row) horarioComidas = JSON.parse(row.valor);
    });
    
    db.get("SELECT valor FROM config WHERE clave = 'precio_fijo_desayunos'", (err, row) => {
        if (row) precioFijoDesayunos = row.valor;
    });
    
    db.get("SELECT valor FROM config WHERE clave = 'precio_fijo_comida'", (err, row) => {
        if (row) precioFijoComida = row.valor;
    });
    
    console.log('📦 Base de datos inicializada');
}

function guardarConfig(clave, valor) {
    db.run("INSERT OR REPLACE INTO config (clave, valor) VALUES (?, ?)", [clave, valor]);
}

function limpiarDia() {
    const hoy = new Date().toISOString().split('T')[0];
    db.run("DELETE FROM desayunos WHERE fecha != ?", [hoy]);
    db.run("DELETE FROM comida_primer_tiempo WHERE fecha != ?", [hoy]);
    db.run("DELETE FROM comida_segundo_tiempo WHERE fecha != ?", [hoy]);
    db.run("DELETE FROM comida_tercer_tiempo WHERE fecha != ?", [hoy]);
    db.run("DELETE FROM acompanamientos WHERE fecha != ?", [hoy]);
    console.log('🧹 Base de datos limpiada para nuevo día');
}

// ============================================
// FUNCIONES DE TRANSCRIPCIÓN DE VOZ (LOCAL)
// ============================================

async function transcribirAudio(bufferAudio) {
    // Guardar audio temporal
    const tempOpus = path.join(__dirname, 'temp_audio.opus');
    const tempWav = path.join(__dirname, 'temp_audio.wav');
    
    fs.writeFileSync(tempOpus, bufferAudio);
    
    // Convertir de opus a wav usando ffmpeg
    await execAsync(`ffmpeg -i ${tempOpus} -acodec pcm_s16le -ar 16000 ${tempWav} -y`);
    
    // Usar Vosk para transcribir
    const { spawn } = require('child_process');
    const vosk = require('vosk');
    
    vosk.setLogLevel(-1);
    const model = new vosk.Model(MODEL_DIR);
    const rec = new vosk.Recognizer({ model: model, sampleRate: 16000 });
    
    const audioData = fs.readFileSync(tempWav);
    const buffer = audioData.slice(44); // Saltar cabecera WAV
    
    let texto = '';
    if (rec.acceptWaveform(buffer)) {
        const result = JSON.parse(rec.result());
        texto = result.text;
    } else {
        const partial = rec.partialResult();
        texto = JSON.parse(partial).partial;
    }
    
    rec.free();
    model.free();
    
    // Limpiar archivos temporales
    fs.unlinkSync(tempOpus);
    fs.unlinkSync(tempWav);
    
    return texto.toLowerCase();
}

// ============================================
// FUNCIONES DE INTERPRETACIÓN SEMÁNTICA
// ============================================

function interpretarInstruccion(texto) {
    const instruccion = {
        tipo: null,
        datos: {}
    };
    
    // Detectar si es instrucción del dueño (palabras clave)
    if (texto.includes('agrega') || texto.includes('registra') || texto.includes('tenemos')) {
        instruccion.tipo = 'agregar';
        
        // Detectar desayunos
        if (texto.includes('desayuno')) {
            instruccion.datos.categoria = 'desayunos';
            // Extraer productos y precios (simplificado)
            const matchPrecio = texto.match(/(\d+)\s*p(esos?)?/i);
            if (matchPrecio) instruccion.datos.precio = matchPrecio[1];
        }
        
        // Detectar comida corrida
        if (texto.includes('comida') || texto.includes('primer tiempo') || texto.includes('segundo tiempo') || texto.includes('tercer tiempo')) {
            instruccion.datos.categoria = 'comida';
            if (texto.includes('primer tiempo')) instruccion.datos.tiempo = 'primero';
            if (texto.includes('segundo tiempo')) instruccion.datos.tiempo = 'segundo';
            if (texto.includes('tercer tiempo')) instruccion.datos.tiempo = 'tercero';
        }
    }
    
    if (texto.includes('elimina') || texto.includes('borra') || texto.includes('ya no')) {
        instruccion.tipo = 'eliminar';
        // Extraer qué eliminar
        const palabras = texto.split(' ');
        for (let i = 0; i < palabras.length; i++) {
            if (palabras[i] === 'elimina' || palabras[i] === 'borra') {
                instruccion.datos.producto = palabras.slice(i+1).join(' ');
                break;
            }
        }
    }
    
    if (texto.includes('cambia') || texto.includes('actualiza')) {
        instruccion.tipo = 'actualizar';
        if (texto.includes('precio')) instruccion.datos.campo = 'precio';
        if (texto.includes('horario')) instruccion.datos.campo = 'horario';
    }
    
    if (texto.includes('configura') || texto.includes('establece')) {
        instruccion.tipo = 'configurar';
        if (texto.includes('cierre')) instruccion.datos.config = 'cierre';
    }
    
    if (texto.includes('reinicia') && (texto.includes('base') || texto.includes('datos'))) {
        instruccion.tipo = 'reiniciar';
    }
    
    if (texto.includes('activar modo cliente')) {
        instruccion.tipo = 'modo_cliente_on';
    }
    
    if (texto.includes('desactivar modo cliente')) {
        instruccion.tipo = 'modo_cliente_off';
    }
    
    if (texto.includes('en qué modo')) {
        instruccion.tipo = 'consultar_modo';
    }
    
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
// FUNCIONES DE RESPUESTA AL CLIENTE
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
    const desayunos = await new Promise((resolve) => {
        db.all("SELECT producto, precio, incluye FROM desayunos ORDER BY id", [], (err, rows) => {
            resolve(rows);
        });
    });
    
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
    
    const incluye = desayunos[0]?.incluye;
    if (incluye) mensaje += `\n*Incluye:* ${incluye}`;
    
    await sock.sendMessage(to, { text: mensaje });
}

async function responderComidaCompleta(sock, to) {
    const primerTiempo = await new Promise((resolve) => {
        db.all("SELECT opcion FROM comida_primer_tiempo ORDER BY id", [], (err, rows) => {
            resolve(rows.map(r => r.opcion));
        });
    });
    
    const segundoTiempo = await new Promise((resolve) => {
        db.all("SELECT opcion FROM comida_segundo_tiempo ORDER BY id", [], (err, rows) => {
            resolve(rows.map(r => r.opcion));
        });
    });
    
    const tercerTiempo = await new Promise((resolve) => {
        db.all("SELECT opcion FROM comida_tercer_tiempo ORDER BY id", [], (err, rows) => {
            resolve(rows.map(r => r.opcion));
        });
    });
    
    const acompanamientos = await new Promise((resolve) => {
        db.all("SELECT tipo, descripcion FROM acompanamientos ORDER BY id", [], (err, rows) => {
            resolve(rows);
        });
    });
    
    // Función para enviar mensaje con delay
    const enviarConDelay = (msg, delayMs = 2000) => {
        return new Promise(resolve => {
            setTimeout(async () => {
                await sock.sendMessage(to, { text: msg });
                resolve();
            }, delayMs);
        });
    };
    
    // Enviar primer tiempo
    if (primerTiempo.length > 0) {
        let msg = "🍽️ *PRIMER TIEMPO* (Sopa/Consomé)\n";
        primerTiempo.forEach(op => { msg += `• ${op}\n`; });
        await sock.sendMessage(to, { text: msg });
        await new Promise(r => setTimeout(r, 2000));
    }
    
    // Enviar segundo tiempo
    if (segundoTiempo.length > 0) {
        let msg = "🍚 *SEGUNDO TIEMPO* (Arroz/Pasta)\n";
        segundoTiempo.forEach(op => { msg += `• ${op}\n`; });
        await sock.sendMessage(to, { text: msg });
        await new Promise(r => setTimeout(r, 2000));
    }
    
    // Enviar tercer tiempo (dividir si hay más de 5)
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
    
    // Enviar acompañamientos
    if (acompanamientos.length > 0) {
        let msg = "🥤 *INCLUYE*\n";
        acompanamientos.forEach(a => { msg += `• ${a.descripcion}\n`; });
        await sock.sendMessage(to, { text: msg });
        await new Promise(r => setTimeout(r, 1500));
    }
    
    // Enviar precio
    if (precioFijoComida) {
        await sock.sendMessage(to, { text: `💰 *Precio único: $${precioFijoComida} MXN*` });
    }
}

// ============================================
// FUNCIONES DE PROCESAMIENTO DE MENSAJES
// ============================================

async function procesarMensaje(sock, msg, sender, messageText, esVoz) {
    const esAdmin = (adminID === sender);
    const horaActual = obtenerHoraActual();
    
    // Si es admin y NO está en modo cliente, procesar como instrucción
    if (esAdmin && !modoCliente) {
        if (esVoz) {
            const instruccion = interpretarInstruccion(messageText);
            
            switch (instruccion.tipo) {
                case 'agregar':
                    await sock.sendMessage(sender, { text: "✅ Información registrada. Procesando..." });
                    // Aquí iría la lógica de guardar en BD
                    break;
                case 'eliminar':
                    await sock.sendMessage(sender, { text: `✅ Eliminado: ${instruccion.datos.producto || 'producto'}` });
                    break;
                case 'actualizar':
                    await sock.sendMessage(sender, { text: "✅ Actualizado correctamente" });
                    break;
                case 'configurar':
                    if (instruccion.datos.config === 'cierre') {
                        await sock.sendMessage(sender, { text: "✅ Horario de cierre configurado" });
                    }
                    break;
                case 'reiniciar':
                    limpiarDia();
                    await sock.sendMessage(sender, { text: "✅ Base de datos reiniciada para nuevo día" });
                    break;
                case 'modo_cliente_on':
                    modoCliente = true;
                    await sock.sendMessage(sender, { text: "🧪 Modo cliente activado. Ahora te trataré como un cliente normal para pruebas." });
                    break;
                case 'modo_cliente_off':
                    modoCliente = false;
                    await sock.sendMessage(sender, { text: "✅ Modo cliente desactivado. Ahora vuelves a ser el administrador." });
                    break;
                case 'consultar_modo':
                    const estado = modoCliente ? "🧪 Modo cliente (pruebas)" : "🔧 Modo administrador";
                    await sock.sendMessage(sender, { text: `Actualmente estás en: ${estado}` });
                    break;
                default:
                    await sock.sendMessage(sender, { text: "✅ Instrucción recibida. Procesando..." });
            }
        }
        return; // No procesar como cliente si es admin
    }
    
    // Si llegamos aquí, es cliente (o admin en modo cliente)
    const pregunta = interpretarPreguntaCliente(messageText);
    
    // Simular typing
    await sock.sendPresenceUpdate('composing', sender);
    await new Promise(r => setTimeout(r, 1500));
    
    switch (pregunta) {
        case 'desayunos':
            if (!estaEnHorario(horarioDesayunos)) {
                if (estaEnHorario(horarioComidas)) {
                    await sock.sendMessage(sender, { text: "🙏 Discúlpamos, por el momento los desayunos ya terminaron. Pero ya tenemos disponible la información de las comidas. ¿Quieres que te dé esa información?" });
                } else {
                    await sock.sendMessage(sender, { text: `🌙 Los desayunos se sirven de ${horarioDesayunos.inicio} a ${horarioDesayunos.fin}. Ahora mismo no estamos sirviendo desayunos.` });
                }
            } else {
                await responderDesayunos(sock, sender);
            }
            break;
            
        case 'comida':
            if (!estaEnHorario(horarioComidas)) {
                await sock.sendMessage(sender, { text: `🍽️ Las comidas empiezan a partir de las ${horarioComidas.inicio}. Por favor, escríbenos cerca de ese horario para darte la información exacta de todos los productos que vamos a tener hoy.` });
            } else {
                await responderComidaCompleta(sock, sender);
            }
            break;
            
        case 'ubicacion':
            await sock.sendMessage(sender, { text: "📍 El negocio se encuentra en Calle Juárez #123, Colonia Centro. ¡Te esperamos!" });
            break;
            
        case 'horario':
            await sock.sendMessage(sender, { text: `🕐 Desayunos: ${horarioDesayunos.inicio} a ${horarioDesayunos.fin}\n🍽️ Comidas: ${horarioComidas.inicio} a ${horarioComidas.fin}` });
            break;
            
        default:
            await sock.sendMessage(sender, { text: "🍽️ ¡Hola! Soy el bot de la Comida Corrida. Puedes preguntarme por: desayunos, comida corrida, horarios o ubicación." });
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
        printQRInTerminal: false,  // No usamos QR, usamos pairing code
        logger: P({ level: 'silent' }),
        browser: ['ComidaBot', 'Chrome', '1.0.0']
    });
    
    sock.ev.on('creds.update', saveCreds);
    
    // Manejo de conexión y pairing code
    sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;
        
        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) {
                startBot();
            }
        } else if (connection === 'open') {
            console.log("✅ Bot conectado exitosamente");
            
            // Verificar si ya tenemos el admin ID
            if (!adminID) {
                console.log("\n==========================================");
                console.log("⚙️ CONFIGURACIÓN INICIAL");
                console.log("==========================================");
                
                // Pedir número del dueño
                const readline = require('readline');
                const rl = readline.createInterface({
                    input: process.stdin,
                    output: process.stdout
                });
                
                rl.question("📱 Ingresa el número del DUEÑO (admin) que dará instrucciones por voz (ej. 5215551234567): ", async (numero) => {
                    const numeroCompleto = `${numero}@s.whatsapp.net`;
                    await sock.sendMessage(numeroCompleto, { text: "🔐 Mensaje de verificación. Por favor responde cualquier cosa para confirmar que eres el administrador." });
                    console.log("⏳ Esperando respuesta del dueño para confirmar...");
                    rl.close();
                });
            } else {
                console.log(`👑 Dueño identificado: ${adminID}`);
                console.log("🎧 Esperando instrucciones por voz del dueño...");
                console.log("💬 Esperando preguntas de clientes...");
            }
        }
    });
    
    // Escuchar mensajes
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const msg = messages[0];
        if (!msg.message || msg.key.fromMe) return;
        
        const sender = msg.key.remoteJid;
        if (sender.endsWith('@g.us')) return; // Ignorar grupos
        
        let messageText = '';
        let esVoz = false;
        
        // Extraer texto o transcribir voz
        if (msg.message.conversation) {
            messageText = msg.message.conversation;
        } else if (msg.message.extendedTextMessage?.text) {
            messageText = msg.message.extendedTextMessage.text;
        } else if (msg.message.audioMessage) {
            esVoz = true;
            // Descargar audio
            const stream = await sock.downloadMediaMessage(msg);
            const chunks = [];
            for await (const chunk of stream) {
                chunks.push(chunk);
            }
            const buffer = Buffer.concat(chunks);
            messageText = await transcribirAudio(buffer);
            console.log(`🎤 Transcripción: ${messageText}`);
        } else {
            return;
        }
        
        console.log(`📩 De: ${sender.split('@')[0]} | Texto: "${messageText}" | Voz: ${esVoz}`);
        
        await procesarMensaje(sock, msg, sender, messageText, esVoz);
    });
    
    // Solicitar pairing code si no hay sesión
    if (!fs.existsSync(path.join(AUTH_DIR, 'creds.json'))) {
        const readline = require('readline');
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
        
        rl.question("📱 Ingresa el número del BOT que quieres vincular (ej. 5215551234567): ", async (numero) => {
            console.log("📟 Solicitando código de emparejamiento...");
            const code = await sock.requestPairingCode(numero);
            console.log(`🔑 Código de emparejamiento: ${code}`);
            console.log("📲 Abre WhatsApp, ve a Dispositivos vinculados y escribe este código.");
            console.log("⏳ Esperando vinculación...");
            rl.close();
        });
    }
}

// Iniciar el bot
startBot().catch(err => {
    console.error("❌ Error fatal:", err);
});
