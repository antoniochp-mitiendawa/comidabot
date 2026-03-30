#!/usr/bin/env node

// ============================================
// COMIDABOT - Bot de WhatsApp para Comida Corrida
// Versión: 2.0.0 (con NLP + cola + delay humano + spintax + emojis dinámicos)
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
// CONFIGURACIÓN INICIAL
// ============================================

let adminID = null;
let modoCliente = false;
let rubroNegocio = 'general'; // comida, peluqueria, taller, etc.
let horarioCierre = null;
let db;
let colaMensajes = [];
let procesandoCola = false;
let contadorRespuestasPorMinuto = 0;
let ultimoResetContador = Date.now();

// Directorios
const AUTH_DIR = './auth_info';
const DB_DIR = './db';
const TEMP_AUDIO_DIR = './temp_audio';
const WHISPER_CLI = '/data/data/com.termux/files/home/.local/bin/whisper-cli';
const WHISPER_MODEL = '/data/data/com.termux/files/home/whisper.cpp/models/ggml-base.bin';

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
// EMOJIS DINÁMICOS SEGÚN RUBRO
// ============================================

function getEmojisPorRubro() {
    if (rubroNegocio === 'comida') {
        return { principal: '🍽️', positivo: '✅', saludo: '🍳', producto: '🥘', ubicacion: '📍', horario: '🕐', oferta: '🎉' };
    } else if (rubroNegocio === 'peluqueria') {
        return { principal: '✂️', positivo: '✅', saludo: '💈', producto: '💇', ubicacion: '📍', horario: '🕐', oferta: '✨' };
    } else if (rubroNegocio === 'taller') {
        return { principal: '🔧', positivo: '✅', saludo: '🚗', producto: '⚙️', ubicacion: '📍', horario: '🕐', oferta: '🔩' };
    } else {
        return { principal: '🤘', positivo: '✅', saludo: '🎸', producto: '🔥', ubicacion: '📍', horario: '🕐', oferta: '⚡' };
    }
}

// ============================================
// SALUDO SEGÚN HORARIO
// ============================================

function getSaludoPorHorario() {
    const hora = new Date().getHours();
    if (hora >= 6 && hora < 12) return spintax('{Buenos días|Buen día|¡Hola! Buenos días|Saludos, buenos días}');
    if (hora >= 12 && hora < 19) return spintax('{Buenas tardes|Muy buenas tardes|¡Hola! Buenas tardes|Saludos, buenas tardes}');
    return spintax('{Buenas noches|Muy buenas noches|¡Hola! Buenas noches|Saludos, buenas noches}');
}

// ============================================
// BASE DE DATOS DINÁMICA
// ============================================

function initDatabase() {
    if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR);
    db = new Database(path.join(DB_DIR, 'comidabot.db'));
    
    // Tabla genérica para almacenar cualquier información
    db.exec(`CREATE TABLE IF NOT EXISTS info (
        clave TEXT PRIMARY KEY,
        valor TEXT,
        rubro TEXT,
        fecha TEXT
    )`);
    
    // Tabla para productos/servicios
    db.exec(`CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        precio TEXT,
        descripcion TEXT,
        fecha TEXT
    )`);
    
    // Tabla para configuración
    db.exec(`CREATE TABLE IF NOT EXISTS config (
        clave TEXT PRIMARY KEY,
        valor TEXT
    )`);
    
    // Cargar configuración guardada
    const adminRow = db.prepare("SELECT valor FROM config WHERE clave = 'admin_id'").get();
    if (adminRow) adminID = adminRow.valor;
    
    const rubroRow = db.prepare("SELECT valor FROM config WHERE clave = 'rubro'").get();
    if (rubroRow) rubroNegocio = rubroRow.valor;
    
    console.log('📦 Base de datos dinámica inicializada');
}

function guardarInfo(clave, valor) {
    const hoy = new Date().toISOString().split('T')[0];
    const stmt = db.prepare("INSERT OR REPLACE INTO info (clave, valor, rubro, fecha) VALUES (?, ?, ?, ?)");
    stmt.run(clave, valor, rubroNegocio, hoy);
    console.log(`💾 Guardado: ${clave} = ${valor}`);
}

function obtenerInfo(clave) {
    const stmt = db.prepare("SELECT valor FROM info WHERE clave = ?");
    const row = stmt.get(clave);
    return row ? row.valor : null;
}

function guardarProducto(nombre, precio, descripcion = '') {
    const hoy = new Date().toISOString().split('T')[0];
    const stmt = db.prepare("INSERT INTO productos (nombre, precio, descripcion, fecha) VALUES (?, ?, ?, ?)");
    stmt.run(nombre, precio, descripcion, hoy);
}

function obtenerProductos() {
    const stmt = db.prepare("SELECT nombre, precio, descripcion FROM productos ORDER BY id");
    return stmt.all();
}

function eliminarProducto(nombre) {
    const stmt = db.prepare("DELETE FROM productos WHERE nombre = ?");
    stmt.run(nombre);
}

function guardarConfig(clave, valor) {
    const stmt = db.prepare("INSERT OR REPLACE INTO config (clave, valor) VALUES (?, ?)");
    stmt.run(clave, valor);
}

// ============================================
// NLP - ENTRENAMIENTO CON SINÓNIMOS
// ============================================

const nlpManager = new NlpManager({ languages: ['es'], forceNER: true });

// Entrenar intenciones del dueño
async function entrenarNLP() {
    // Intención: guardar nombre del negocio
    nlpManager.addDocument('es', 'el negocio se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'mi tienda se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'mi local se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'mi emprendimiento se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'mi cafetería se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'mi barbería se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'mi taller se llama {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'registra el nombre como {nombre}', 'negocio.nombre');
    nlpManager.addDocument('es', 'el nombre del negocio es {nombre}', 'negocio.nombre');
    
    // Intención: guardar ubicación
    nlpManager.addDocument('es', 'estamos en {ubicacion}', 'negocio.ubicacion');
    nlpManager.addDocument('es', 'la dirección es {ubicacion}', 'negocio.ubicacion');
    nlpManager.addDocument('es', 'nos ubicamos en {ubicacion}', 'negocio.ubicacion');
    nlpManager.addDocument('es', 'el negocio está en {ubicacion}', 'negocio.ubicacion');
    nlpManager.addDocument('es', 'mi dirección es {ubicacion}', 'negocio.ubicacion');
    
    // Intención: guardar horario
    nlpManager.addDocument('es', 'abrimos de {horario}', 'negocio.horario');
    nlpManager.addDocument('es', 'el horario es {horario}', 'negocio.horario');
    nlpManager.addDocument('es', 'atendemos de {horario}', 'negocio.horario');
    nlpManager.addDocument('es', 'nuestro horario de atención es {horario}', 'negocio.horario');
    
    // Intención: guardar producto con precio
    nlpManager.addDocument('es', '{producto} cuesta {precio} pesos', 'producto.agregar');
    nlpManager.addDocument('es', '{producto} vale {precio}', 'producto.agregar');
    nlpManager.addDocument('es', 'los {producto} cuestan {precio}', 'producto.agregar');
    nlpManager.addDocument('es', 'tenemos {producto} a {precio}', 'producto.agregar');
    
    // Intención: eliminar producto
    nlpManager.addDocument('es', 'elimina {producto}', 'producto.eliminar');
    nlpManager.addDocument('es', 'borra {producto}', 'producto.eliminar');
    nlpManager.addDocument('es', 'ya no tenemos {producto}', 'producto.eliminar');
    
    // Intención: detectar rubro del negocio
    nlpManager.addDocument('es', 'somos un restaurante', 'negocio.rubro.comida');
    nlpManager.addDocument('es', 'somos una comida corrida', 'negocio.rubro.comida');
    nlpManager.addDocument('es', 'somos una barbería', 'negocio.rubro.peluqueria');
    nlpManager.addDocument('es', 'somos una peluquería', 'negocio.rubro.peluqueria');
    nlpManager.addDocument('es', 'somos un taller mecánico', 'negocio.rubro.taller');
    
    // Comandos del dueño (modo cliente/dueño)
    nlpManager.addDocument('es', 'activar modo cliente', 'modo.cliente.on');
    nlpManager.addDocument('es', 'modo cliente', 'modo.cliente.on');
    nlpManager.addDocument('es', 'desactivar modo cliente', 'modo.cliente.off');
    nlpManager.addDocument('es', 'modo dueño', 'modo.cliente.off');
    nlpManager.addDocument('es', 'salir modo cliente', 'modo.cliente.off');
    nlpManager.addDocument('es', 'activar modo admin', 'modo.cliente.off');
    
    // Preguntas de clientes
    nlpManager.addDocument('es', 'cómo se llama el negocio', 'cliente.pregunta.nombre');
    nlpManager.addDocument('es', 'cómo se llama tu negocio', 'cliente.pregunta.nombre');
    nlpManager.addDocument('es', 'qué nombre tiene el negocio', 'cliente.pregunta.nombre');
    nlpManager.addDocument('es', 'cuál es el nombre', 'cliente.pregunta.nombre');
    
    nlpManager.addDocument('es', 'dónde estás ubicado', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'dónde está tu negocio', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'cuál es tu dirección', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'en qué calle están', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'cómo llegar', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'dónde te ubicas', 'cliente.pregunta.ubicacion');
    nlpManager.addDocument('es', 'dirección del negocio', 'cliente.pregunta.ubicacion');
    
    nlpManager.addDocument('es', 'qué horario tienen', 'cliente.pregunta.horario');
    nlpManager.addDocument('es', 'a qué hora abren', 'cliente.pregunta.horario');
    nlpManager.addDocument('es', 'cuándo atienden', 'cliente.pregunta.horario');
    nlpManager.addDocument('es', 'horario de atención', 'cliente.pregunta.horario');
    
    nlpManager.addDocument('es', 'qué productos tienen', 'cliente.pregunta.productos');
    nlpManager.addDocument('es', 'qué venden', 'cliente.pregunta.productos');
    nlpManager.addDocument('es', 'qué ofrecen', 'cliente.pregunta.productos');
    nlpManager.addDocument('es', 'cuál es el menú', 'cliente.pregunta.productos');
    nlpManager.addDocument('es', 'qué servicios ofrecen', 'cliente.pregunta.productos');
    
    // Entrenar
    await nlpManager.train();
    console.log('🧠 NLP entrenado con sinónimos');
}

// ============================================
// PROCESAR MENSAJE CON NLP
// ============================================

async function procesarConNLP(texto, esAdmin) {
    const result = await nlpManager.process('es', texto);
    const intent = result.intent;
    const entities = result.entities;
    
    console.log(`🧠 NLP: Intención=${intent}, Entidades=${JSON.stringify(entities)}`);
    
    // Procesar según la intención
    if (intent === 'negocio.nombre' && esAdmin) {
        const nombre = entities.nombre || texto.match(/llama\s+(.+)$/i)?.[1] || texto;
        guardarInfo('nombre_negocio', nombre);
        return `✅ Nombre del negocio guardado como: ${nombre}`;
    }
    
    if (intent === 'negocio.ubicacion' && esAdmin) {
        const ubicacion = entities.ubicacion || texto.match(/en\s+(.+)$/i)?.[1] || texto;
        guardarInfo('ubicacion', ubicacion);
        return `✅ Ubicación guardada: ${ubicacion}`;
    }
    
    if (intent === 'negocio.horario' && esAdmin) {
        const horario = entities.horario || texto.match(/de\s+(.+)$/i)?.[1] || texto;
        guardarInfo('horario', horario);
        return `✅ Horario guardado: ${horario}`;
    }
    
    if (intent === 'producto.agregar' && esAdmin) {
        const producto = entities.producto || '';
        const precio = entities.precio || '';
        if (producto && precio) {
            guardarProducto(producto, precio);
            return `✅ Producto agregado: ${producto} - $${precio}`;
        }
    }
    
    if (intent === 'producto.eliminar' && esAdmin) {
        const producto = entities.producto || texto.replace(/elimina|borra|ya no tenemos/i, '').trim();
        if (producto) {
            eliminarProducto(producto);
            return `✅ Producto eliminado: ${producto}`;
        }
    }
    
    if (intent === 'negocio.rubro.comida' && esAdmin) {
        rubroNegocio = 'comida';
        guardarConfig('rubro', 'comida');
        return `✅ Rubro configurado: Restaurante/Comida 🍽️`;
    }
    
    if (intent === 'negocio.rubro.peluqueria' && esAdmin) {
        rubroNegocio = 'peluqueria';
        guardarConfig('rubro', 'peluqueria');
        return `✅ Rubro configurado: Peluquería/Barbería ✂️`;
    }
    
    if (intent === 'negocio.rubro.taller' && esAdmin) {
        rubroNegocio = 'taller';
        guardarConfig('rubro', 'taller');
        return `✅ Rubro configurado: Taller Mecánico 🔧`;
    }
    
    if (intent === 'modo.cliente.on' && esAdmin) {
        modoCliente = true;
        return `🧪 Modo cliente activado. Ahora te trataré como cliente para pruebas.`;
    }
    
    if (intent === 'modo.cliente.off' && esAdmin) {
        modoCliente = false;
        return `✅ Modo cliente desactivado. Ahora vuelves a ser el administrador.`;
    }
    
    // Respuestas para clientes (o admin en modo cliente)
    if (!esAdmin || modoCliente) {
        if (intent === 'cliente.pregunta.nombre') {
            const nombre = obtenerInfo('nombre_negocio');
            if (nombre) return spintax(`{${getSaludoPorHorario()}|Hola|Qué tal|Saludos}! ${getEmojisPorRubro().principal} El negocio se llama *${nombre}*. ¿Te puedo ayudar con algo más?`);
            return spintax(`{${getSaludoPorHorario()}|Hola|Qué tal}! ${getEmojisPorRubro().principal} Aún no tengo registrado el nombre del negocio. Pregúntale al dueño.`);
        }
        
        if (intent === 'cliente.pregunta.ubicacion') {
            const ubicacion = obtenerInfo('ubicacion');
            if (ubicacion) return spintax(`{${getSaludoPorHorario()}|Claro|Por supuesto}! ${getEmojisPorRubro().ubicacion} Nos ubicamos en: *${ubicacion}*. ¡Te esperamos!`);
            return spintax(`{${getSaludoPorHorario()}|Hola}! ${getEmojisPorRubro().principal} Aún no tengo registrada la ubicación. Pregúntale al dueño.`);
        }
        
        if (intent === 'cliente.pregunta.horario') {
            const horario = obtenerInfo('horario');
            if (horario) return spintax(`{${getSaludoPorHorario()}|Te cuento|Claro}! ${getEmojisPorRubro().horario} Nuestro horario es: *${horario}*.`);
            return spintax(`{${getSaludoPorHorario()}|Hola}! ${getEmojisPorRubro().principal} Aún no tengo registrado el horario. Pregúntale al dueño.`);
        }
        
        if (intent === 'cliente.pregunta.productos') {
            const productos = obtenerProductos();
            if (productos.length > 0) {
                let respuesta = `${getSaludoPorHorario()} ${getEmojisPorRubro().producto} *Lo que ofrecemos:*\n\n`;
                productos.forEach(p => {
                    respuesta += `• ${p.nombre}`;
                    if (p.precio) respuesta += ` - $${p.precio}`;
                    respuesta += `\n`;
                });
                return respuesta;
            }
            return spintax(`{${getSaludoPorHorario()}|Hola}! ${getEmojisPorRubro().principal} Aún no tengo productos registrados. Pregúntale al dueño.`);
        }
    }
    
    return null; // No se procesó ninguna intención
}

// ============================================
// TRANSCRIPCIÓN DE VOZ (Whisper)
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
        if (fs.existsSync(tempOpus)) fs.unlinkSync(tempOpus);
        if (fs.existsSync(tempWav)) fs.unlinkSync(tempWav);
        if (fs.existsSync(tempTxt)) fs.unlinkSync(tempTxt);
        return texto.toLowerCase();
    } catch (error) {
        console.error('Error en transcripción:', error.message);
        if (fs.existsSync(tempOpus)) fs.unlinkSync(tempOpus);
        if (fs.existsSync(tempWav)) fs.unlinkSync(tempWav);
        if (fs.existsSync(tempTxt)) fs.unlinkSync(tempTxt);
        return '';
    }
}

// ============================================
// COLA DE MENSAJES Y DELAY HUMANO
// ============================================

async function enviarConDelay(sock, to, texto) {
    const delayMs = Math.floor(Math.random() * (14000 - 7000 + 1) + 7000); // 7-14 segundos
    console.log(`⏳ Esperando ${delayMs/1000} segundos antes de responder...`);
    
    // Mostrar "escribiendo..."
    await sock.sendPresenceUpdate('composing', to);
    await delay(delayMs);
    
    await sock.sendMessage(to, { text: texto });
    console.log(`✅ Respuesta enviada después de ${delayMs/1000}s`);
}

async function procesarCola(sock) {
    if (procesandoCola) return;
    procesandoCola = true;
    
    while (colaMensajes.length > 0) {
        const { sock: sockRef, to, texto } = colaMensajes.shift();
        
        // Rate limiting: máximo 10 mensajes por minuto
        const ahora = Date.now();
        if (ahora - ultimoResetContador > 60000) {
            contadorRespuestasPorMinuto = 0;
            ultimoResetContador = ahora;
        }
        
        if (contadorRespuestasPorMinuto >= 10) {
            console.log('⏸️ Rate limit alcanzado, esperando 30 segundos...');
            await delay(30000);
            contadorRespuestasPorMinuto = 0;
        }
        
        await enviarConDelay(sockRef, to, texto);
        contadorRespuestasPorMinuto++;
    }
    
    procesandoCola = false;
}

function agregarACola(sock, to, texto) {
    colaMensajes.push({ sock, to, texto });
    procesarCola(sock);
}

// ============================================
// PROCESAMIENTO DE MENSAJES (con NLP y respaldo)
// ============================================

async function procesarMensaje(sock, msg, sender, messageText, esVoz) {
    const esAdmin = (adminID === sender);
    
    // Si es admin y NO está en modo cliente, intentar procesar con NLP
    if (esAdmin && !modoCliente) {
        const respuestaNLP = await procesarConNLP(messageText, true);
        if (respuestaNLP) {
            agregarACola(sock, sender, respuestaNLP);
            return;
        }
        // Si NLP no entendió, responder genérico
        agregarACola(sock, sender, `✅ Instrucción recibida. ${getEmojisPorRubro().positivo} Procesando...`);
        return;
    }
    
    // Cliente (o admin en modo cliente)
    const respuestaNLP = await procesarConNLP(messageText, false);
    if (respuestaNLP) {
        agregarACola(sock, sender, respuestaNLP);
        return;
    }
    
    // Respuesta por defecto si NLP no entendió
    const respuestaDefault = spintax(`{${getSaludoPorHorario()}|Hola|Qué tal|Saludos}! ${getEmojisPorRubro().principal} Puedes preguntarme por: el nombre del negocio, ubicación, horario o productos. ¿En qué te ayudo?`);
    agregarACola(sock, sender, respuestaDefault);
}

// ============================================
// INICIO DEL BOT
// ============================================

async function startBot() {
    console.log("🚀 Iniciando ComidaBot...");
    initDatabase();
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
                console.log(`🏢 Rubro: ${rubroNegocio}`);
                console.log("🎧 Esperando instrucciones por voz...");
                console.log("💬 Esperando preguntas de clientes...");
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
        
        console.log(`📩 De: ${sender.split('@')[0]} | "${messageText}"`);
        
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
    
    if (!sock.authState.creds.registered) {
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
