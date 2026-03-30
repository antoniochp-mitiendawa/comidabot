#!/usr/bin/env node

// ============================================
// COMIDABOT - Bot de WhatsApp
// Versión: 3.0.0 (DEFINITIVA)
// - Vinculación original (funciona)
// - Sin sendPresenceUpdate (sin peticiones extras)
// - Filtrado de grupos/canales/transmisiones
// - BD dinámica clave-valor
// - IA con NER para extraer entidades
// - Spintax + emojis + formato profesional
// - Delay 6-14 segundos
// - Logging completo
// ============================================

const { default: makeWASocket, useMultiFileAuthState, DisconnectReason, delay, fetchLatestBaileysVersion, downloadMediaMessage } = require('@whiskeysockets/baileys');
const { Boom } = require('@hapi/boom');
const P = require('pino');
const fs = require('fs');
const path = require('path');
const Database = require('yskj-sqlite-android');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const readline = require('readline');
const { NlpManager } = require('node-nlp');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (text) => new Promise((resolve) => rl.question(text, resolve));

// ============================================
// SPRINTAX (texto aleatorio)
// ============================================

function spintax(texto) {
    return texto.replace(/{([^{}]+)}/g, (match, opciones) => {
        const choices = opciones.split('|');
        return choices[Math.floor(Math.random() * choices.length)];
    });
}

// ============================================
// EMOJIS SEGÚN RUBRO
// ============================================

let rubroNegocio = 'general';
const emojisPorRubro = {
    comida: { principal: '🍽️', positivo: '✅', saludo: '🍳', producto: '🥘', ubicacion: '📍', horario: '🕐' },
    peluqueria: { principal: '✂️', positivo: '✅', saludo: '💈', producto: '💇', ubicacion: '📍', horario: '🕐' },
    taller: { principal: '🔧', positivo: '✅', saludo: '🚗', producto: '⚙️', ubicacion: '📍', horario: '🕐' },
    general: { principal: '🤘', positivo: '✅', saludo: '🎸', producto: '🔥', ubicacion: '📍', horario: '🕐' }
};

function getEmojis() {
    return emojisPorRubro[rubroNegocio] || emojisPorRubro.general;
}

// ============================================
// SALUDO SEGÚN HORARIO
// ============================================

function getSaludo() {
    const hora = new Date().getHours();
    if (hora >= 6 && hora < 12) return spintax('{Buenos días|Buen día|¡Hola! Buenos días}');
    if (hora >= 12 && hora < 19) return spintax('{Buenas tardes|Muy buenas tardes|¡Hola! Buenas tardes}');
    return spintax('{Buenas noches|Muy buenas noches|¡Hola! Buenas noches}');
}

// ============================================
// BASE DE DATOS DINÁMICA (clave-valor)
// ============================================

const DB_DIR = './db';

function initDatabase() {
    if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR);
    const dbPath = path.join(DB_DIR, 'comidabot.db');
    const db = new Database(dbPath);
    
    // Tabla de configuración (dueño, etc.)
    db.exec(`CREATE TABLE IF NOT EXISTS config (
        clave TEXT PRIMARY KEY,
        valor TEXT
    )`);
    
    // Tabla dinámica para información del negocio
    db.exec(`CREATE TABLE IF NOT EXISTS info (
        clave TEXT PRIMARY KEY,
        valor TEXT,
        rubro TEXT,
        fecha TEXT
    )`);
    
    console.log('📦 Base de datos dinámica inicializada');
    return db;
}

let db = initDatabase();

function guardarInfo(clave, valor) {
    const hoy = new Date().toISOString().split('T')[0];
    const stmt = db.prepare("INSERT OR REPLACE INTO info (clave, valor, rubro, fecha) VALUES (?, ?, ?, ?)");
    stmt.run(clave.toLowerCase(), valor, rubroNegocio, hoy);
    console.log(`💾 Guardado: ${clave} = ${valor}`);
}

function obtenerInfo(clave) {
    const stmt = db.prepare("SELECT valor FROM info WHERE clave = ?");
    const row = stmt.get(clave.toLowerCase());
    return row ? row.valor : null;
}

function guardarConfig(clave, valor) {
    const stmt = db.prepare("INSERT OR REPLACE INTO config (clave, valor) VALUES (?, ?)");
    stmt.run(clave, valor);
}

function obtenerConfig(clave) {
    const stmt = db.prepare("SELECT valor FROM config WHERE clave = ?");
    const row = stmt.get(clave);
    return row ? row.valor : null;
}

// ============================================
// IA - NLP CON NER (Named Entity Recognition)
// ============================================

const nlpManager = new NlpManager({ languages: ['es'], forceNER: true, autoSave: false });

async function entrenarNLP() {
    // Entrenar para entender instrucciones del dueño (guardar información)
    nlpManager.addDocument('es', 'el negocio se llama [nombre]', 'negocio.guardar.nombre');
    nlpManager.addDocument('es', 'mi tienda se llama [nombre]', 'negocio.guardar.nombre');
    nlpManager.addDocument('es', 'el local se llama [nombre]', 'negocio.guardar.nombre');
    nlpManager.addDocument('es', 'estamos en [ubicacion]', 'negocio.guardar.ubicacion');
    nlpManager.addDocument('es', 'la dirección es [ubicacion]', 'negocio.guardar.ubicacion');
    nlpManager.addDocument('es', 'abrimos de [horario]', 'negocio.guardar.horario');
    nlpManager.addDocument('es', 'el horario es [horario]', 'negocio.guardar.horario');
    nlpManager.addDocument('es', '[producto] cuesta [precio] pesos', 'negocio.guardar.producto');
    nlpManager.addDocument('es', 'tenemos [producto] a [precio]', 'negocio.guardar.producto');
    nlpManager.addDocument('es', 'somos un restaurante', 'negocio.rubro.comida');
    nlpManager.addDocument('es', 'somos una barbería', 'negocio.rubro.peluqueria');
    nlpManager.addDocument('es', 'somos un taller mecánico', 'negocio.rubro.taller');
    
    // Comandos del dueño
    nlpManager.addDocument('es', 'activar modo cliente', 'modo.cliente.on');
    nlpManager.addDocument('es', 'modo cliente', 'modo.cliente.on');
    nlpManager.addDocument('es', 'desactivar modo cliente', 'modo.cliente.off');
    nlpManager.addDocument('es', 'modo dueño', 'modo.cliente.off');
    nlpManager.addDocument('es', 'activar modo dueño', 'modo.cliente.off');
    nlpManager.addDocument('es', 'salir modo cliente', 'modo.cliente.off');
    nlpManager.addDocument('es', 'volver modo dueño', 'modo.cliente.off');
    
    // Preguntas de clientes
    nlpManager.addDocument('es', 'cómo se llama el negocio', 'cliente.pregunta.nombre');
    nlpManager.addDocument('es', 'dónde están ubicados', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'qué horario tienen', 'cliente.pregunta.horario');
    nlpManager.addDocument('es', 'qué productos ofrecen', 'cliente.pregunta.productos');
    nlpManager.addDocument('es', 'gracias', 'cliente.gracias');
    nlpManager.addDocument('es', 'muchas gracias', 'cliente.gracias');
    
    // Entrenar
    await nlpManager.train();
    console.log('🧠 IA entrenada (NER + clasificación de intenciones)');
}

// Función para procesar mensaje con IA
async function procesarConIA(texto, esAdmin) {
    const result = await nlpManager.process('es', texto);
    const intent = result.intent;
    const entities = result.entities;
    
    console.log(`🧠 IA: Intención=${intent} | Entidades=${JSON.stringify(entities)}`);
    
    // Procesar según la intención (solo para el dueño)
    if (esAdmin) {
        if (intent === 'negocio.guardar.nombre' && entities.nombre) {
            guardarInfo('nombre_negocio', entities.nombre);
            return spintax(`{✅ Listo|✅ Guardado|✅ Registrado} ${getEmojis().positivo} El nombre del negocio es *${entities.nombre}*.`);
        }
        if (intent === 'negocio.guardar.ubicacion' && entities.ubicacion) {
            guardarInfo('ubicacion', entities.ubicacion);
            return spintax(`{✅ Ubicación guardada|✅ Dirección registrada} ${getEmojis().ubicacion} *${entities.ubicacion}*`);
        }
        if (intent === 'negocio.guardar.horario' && entities.horario) {
            guardarInfo('horario', entities.horario);
            return spintax(`{✅ Horario guardado|✅ Horario registrado} ${getEmojis().horario} *${entities.horario}*`);
        }
        if (intent === 'negocio.guardar.producto' && entities.producto) {
            const precio = entities.precio || 'consulta';
            guardarInfo(`producto_${entities.producto.toLowerCase()}`, precio);
            return spintax(`{✅ Producto guardado|✅ Registrado} ${getEmojis().producto} *${entities.producto}* ${precio !== 'consulta' ? `- $${precio}` : ''}`);
        }
        if (intent === 'negocio.rubro.comida') {
            rubroNegocio = 'comida';
            guardarConfig('rubro', 'comida');
            return spintax(`{✅ Rubro configurado|✅ Listo} ${getEmojisPorRubro().principal} *Restaurante/Comida*`);
        }
        if (intent === 'negocio.rubro.peluqueria') {
            rubroNegocio = 'peluqueria';
            guardarConfig('rubro', 'peluqueria');
            return spintax(`{✅ Rubro configurado|✅ Listo} ${getEmojisPorRubro().principal} *Peluquería/Barbería*`);
        }
        if (intent === 'negocio.rubro.taller') {
            rubroNegocio = 'taller';
            guardarConfig('rubro', 'taller');
            return spintax(`{✅ Rubro configurado|✅ Listo} ${getEmojisPorRubro().principal} *Taller Mecánico*`);
        }
        if (intent === 'modo.cliente.on') {
            return spintax(`{🧪 Modo cliente activado|🧪 Modo prueba activado}. Ahora te responderé como cliente.`);
        }
        if (intent === 'modo.cliente.off') {
            return spintax(`{✅ Modo dueño activado|✅ Modo administrador activado}. Ahora puedes darme instrucciones.`);
        }
    }
    
    // Respuestas para clientes (o admin en modo cliente)
    if (!esAdmin) {
        if (intent === 'cliente.pregunta.nombre') {
            const nombre = obtenerInfo('nombre_negocio');
            if (nombre) {
                return spintax(`{${getSaludo()}|Claro|Por supuesto} ${getEmojis().principal} El negocio se llama *${nombre}*.`);
            }
            return spintax(`{${getSaludo()}|Disculpa} ${getEmojis().principal} Aún no tengo el nombre del negocio registrado.`);
        }
        if (intent === 'cliente.pregunta.ubicacion') {
            const ubicacion = obtenerInfo('ubicacion');
            if (ubicacion) {
                return spintax(`{${getSaludo()}|Claro|Por supuesto} ${getEmojis().ubicacion} Nos ubicamos en *${ubicacion}*. ¡Te esperamos!`);
            }
            return spintax(`{${getSaludo()}|Disculpa} ${getEmojis().principal} Aún no tengo la ubicación registrada.`);
        }
        if (intent === 'cliente.pregunta.horario') {
            const horario = obtenerInfo('horario');
            if (horario) {
                return spintax(`{${getSaludo()}|Claro|Te cuento} ${getEmojis().horario} Nuestro horario es *${horario}*.`);
            }
            return spintax(`{${getSaludo()}|Disculpa} ${getEmojis().principal} Aún no tengo el horario registrado.`);
        }
        if (intent === 'cliente.pregunta.productos') {
            // Buscar productos guardados (claves que empiecen con "producto_")
            const stmt = db.prepare("SELECT clave, valor FROM info WHERE clave LIKE 'producto_%'");
            const productos = stmt.all();
            if (productos.length > 0) {
                let respuesta = `${getSaludo()} ${getEmojis().producto} *Lo que ofrecemos:*\n\n`;
                productos.forEach(p => {
                    const nombre = p.clave.replace('producto_', '');
                    respuesta += `• *${nombre}*`;
                    if (p.valor && p.valor !== 'consulta') respuesta += ` - $${p.valor}`;
                    respuesta += `\n`;
                });
                return respuesta;
            }
            return spintax(`{${getSaludo()}|Disculpa} ${getEmojis().principal} Aún no tengo productos registrados.`);
        }
        if (intent === 'cliente.gracias') {
            return spintax(`{¡A ti!|Un placer|Gracias a ti|Saludos} ${getEmojis().principal} ¡Que tengas un excelente día!`);
        }
    }
    
    return null; // No se procesó ninguna intención
}

// ============================================
// TRANSCRIPCIÓN DE VOZ (Whisper)
// ============================================

const TEMP_AUDIO_DIR = './temp_audio';
const WHISPER_CLI = '/data/data/com.termux/files/home/.local/bin/whisper-cli';
const WHISPER_MODEL = '/data/data/com.termux/files/home/whisper.cpp/models/ggml-base.bin';

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
        if (fs.existsSync(tempOpus)) fs.unlinkSync(tempOpus);
        if (fs.existsSync(tempWav)) fs.unlinkSync(tempWav);
        if (fs.existsSync(tempTxt)) fs.unlinkSync(tempTxt);
        return texto.toLowerCase();
    } catch (error) {
        console.error('❌ Error en transcripción:', error.message);
        if (fs.existsSync(tempOpus)) fs.unlinkSync(tempOpus);
        if (fs.existsSync(tempWav)) fs.unlinkSync(tempWav);
        if (fs.existsSync(tempTxt)) fs.unlinkSync(tempTxt);
        return '';
    }
}

// ============================================
// COLA DE MENSAJES Y DELAY HUMANO
// ============================================

let colaMensajes = [];
let procesandoCola = false;
let contadorRespuestas = 0;
let ultimoReset = Date.now();

async function enviarConDelay(sock, to, texto) {
    const delayMs = Math.floor(Math.random() * (14000 - 6000 + 1) + 6000); // 6-14 segundos
    console.log(`⏳ Esperando ${(delayMs/1000).toFixed(1)} segundos antes de responder...`);
    await delay(delayMs);
    await sock.sendMessage(to, { text: texto });
    console.log(`📤 Respuesta enviada a ${to.split('@')[0]}: "${texto.substring(0, 100)}${texto.length > 100 ? '...' : ''}"`);
}

async function procesarCola(sock) {
    if (procesandoCola) return;
    procesandoCola = true;
    
    while (colaMensajes.length > 0) {
        const { sock: sockRef, to, texto } = colaMensajes.shift();
        
        // Rate limiting: máximo 15 respuestas por minuto
        const ahora = Date.now();
        if (ahora - ultimoReset > 60000) {
            contadorRespuestas = 0;
            ultimoReset = ahora;
        }
        
        if (contadorRespuestas >= 15) {
            console.log('⏸️ Rate limit alcanzado, esperando 30 segundos...');
            await delay(30000);
            contadorRespuestas = 0;
        }
        
        await enviarConDelay(sockRef, to, texto);
        contadorRespuestas++;
    }
    procesandoCola = false;
}

function agregarACola(sock, to, texto) {
    colaMensajes.push({ sock, to, texto });
    procesarCola(sock);
}

// ============================================
// VARIABLES GLOBALES (ORIGINALES)
// ============================================

let adminID = null;
let modoCliente = false;
const AUTH_DIR = './auth_info';

// ============================================
// PROCESAMIENTO DE MENSAJES
// ============================================

async function procesarMensaje(sock, msg, sender, messageText, esVoz) {
    const esAdmin = (adminID === sender);
    
    console.log(`📩 De: ${sender.split('@')[0]} | "${messageText}"`);
    
    // Si es admin y NO está en modo cliente, intentar con IA
    if (esAdmin && !modoCliente) {
        const respuestaIA = await procesarConIA(messageText, true);
        if (respuestaIA) {
            agregarACola(sock, sender, respuestaIA);
            return;
        }
        // Si la IA no entendió, respuesta genérica
        agregarACola(sock, sender, `✅ Instrucción recibida. ${getEmojis().positivo} Procesando...`);
        return;
    }
    
    // Cliente (o admin en modo cliente)
    const respuestaIA = await procesarConIA(messageText, false);
    if (respuestaIA) {
        agregarACola(sock, sender, respuestaIA);
        return;
    }
    
    // Respuesta por defecto si la IA no entendió
    const respuestaDefault = spintax(`{${getSaludo()}|Hola|Qué tal} ${getEmojis().principal} Puedo ayudarte con: *nombre del negocio*, *ubicación*, *horario* o *productos*. ¿En qué te ayudo?`);
    agregarACola(sock, sender, respuestaDefault);
}

// ============================================
// INICIO DEL BOT (VINCULACIÓN ORIGINAL)
// ============================================

async function startBot() {
    console.log("🚀 Iniciando ComidaBot...");
    
    // Cargar rubro guardado
    const rubroGuardado = obtenerConfig('rubro');
    if (rubroGuardado) rubroNegocio = rubroGuardado;
    
    // Cargar admin guardado
    const adminGuardado = obtenerConfig('admin_id');
    if (adminGuardado) adminID = adminGuardado;
    
    // Entrenar IA
    await entrenarNLP();
    
    const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
    const { version } = await fetchLatestBaileysVersion();
    
    const sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
        logger: P({ level: 'silent' }),
        browser: ['Windows', 'Chrome', '114.0.5735.198']
    });
    
    sock.ev.on('creds.update', saveCreds);
    
    sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect } = update;
        
        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) {
                console.log("🔄 Reconectando...");
                startBot();
            }
        } else if (connection === 'open') {
            console.log("✅ Bot conectado exitosamente");
            
            if (!adminID) {
                console.log("\n==========================================");
                console.log("⚙️ CONFIGURACIÓN INICIAL - DUEÑO");
                console.log("==========================================");
                
                const numero = await question("📱 Ingresa el número del DUEÑO (admin): ");
                const numeroCompleto = `${numero}@s.whatsapp.net`;
                await sock.sendMessage(numeroCompleto, { text: "🔐 Responde para confirmar que eres el administrador" });
                console.log("⏳ Esperando respuesta...");
            } else {
                console.log(`👑 Dueño: ${adminID}`);
                console.log(`🏢 Rubro: ${rubroNegocio} ${getEmojis().principal}`);
                console.log("🎧 Esperando instrucciones por voz...");
                console.log("💬 Esperando preguntas de clientes...");
            }
        }
    });
    
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const msg = messages[0];
        if (!msg.message || msg.key.fromMe) return;
        
        const sender = msg.key.remoteJid;
        
        // ============================================
        // FILTRADO ESTRICTO DE MENSAJES
        // Solo cuentas individuales (@s.whatsapp.net o @lid)
        // ============================================
        if (sender.includes('@g.us')) return;      // Grupos
        if (sender.includes('@broadcast')) return; // Transmisiones
        if (sender.includes('@newsletter')) return;// Canales
        if (!sender.includes('@s.whatsapp.net') && !sender.includes('@lid')) return; // Solo individuales
        
        let messageText = '';
        let esVoz = false;
        
        if (msg.message.conversation) {
            messageText = msg.message.conversation;
        } else if (msg.message.extendedTextMessage?.text) {
            messageText = msg.message.extendedTextMessage.text;
        } else if (msg.message.audioMessage) {
            esVoz = true;
            try {
                const stream = await downloadMediaMessage(
                    msg,
                    'stream',
                    {},
                    { reuploadRequest: sock.updateMediaMessage }
                );
                
                const chunks = [];
                for await (const chunk of stream) {
                    chunks.push(chunk);
                }
                const buffer = Buffer.concat(chunks);
                
                if (!buffer || buffer.length === 0) {
                    console.log("⚠️ Buffer de audio vacío");
                    return;
                }
                
                messageText = await transcribirAudio(buffer);
                console.log(`🎤 Transcripción: ${messageText}`);
            } catch (error) {
                console.error("❌ Error descargando audio:", error.message);
                return;
            }
        } else {
            return;
        }
        
        // Verificar si es la respuesta de verificación del dueño
        if (adminID === null && sender !== 'status@broadcast') {
            adminID = sender;
            guardarConfig('admin_id', adminID);
            console.log(`✅ Dueño verificado: ${adminID}`);
            await sock.sendMessage(sender, { text: "✅ Eres el administrador. Puedes darme instrucciones por voz." });
            return;
        }
        
        await procesarMensaje(sock, msg, sender, messageText, esVoz);
    });
    
    // ============================================
    // VINCULACIÓN ORIGINAL (LA QUE FUNCIONA)
    // ============================================
    if (!fs.existsSync(path.join(AUTH_DIR, 'creds.json'))) {
        console.log("\n==========================================");
        console.log("🔐 VINCULACIÓN DEL BOT");
        console.log("==========================================");
        await delay(5000);
        const numero = await question("📱 Ingresa el número del BOT que quieres vincular (ej. 5215551234567): ");
        const codigo = await sock.requestPairingCode(numero.trim());
        console.log(`\n🔑 CÓDIGO DE EMPAREJAMIENTO: ${codigo}`);
        console.log("📲 Abre WhatsApp, ve a Dispositivos vinculados y escribe este código.\n");
        console.log("⏳ Esperando vinculación...");
    }
}

startBot().catch(err => console.error("❌ Error fatal:", err));
