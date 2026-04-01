import { makeWASocket, useMultiFileAuthState, fetchLatestBaileysVersion, makeCacheableSignalKeyStore, DisconnectReason } from '@whiskeysockets/baileys';
import pino from 'pino';
import { Boom } from '@hapi/boom';
import { Ollama } from 'ollama'; // Corrección de Sintaxis: Importación de Clase
import dotenv from 'dotenv';
import fs from 'fs';

dotenv.config();

// Inicializamos Ollama con la clase correcta
const ollama = new Ollama({ host: 'http://127.0.0.1:11434' });

async function startBot() {
    const { state, saveCreds } = await useMultiFileAuthState('session_auth');
    const { version } = await fetchLatestBaileysVersion();

    // 1. EXTRAER NÚMERO DEL BOT DEL .ENV
    const BOT_NUMBER = process.env.BOT_NUMBER;

    const sock = makeWASocket({
        version,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false,
        auth: {
            creds: state.creds,
            keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' })),
        },
        browser: ["Ubuntu", "Chrome", "20.0.04"],
    });

    // 2. SOLICITUD DE CÓDIGO (PASO 1 DEL FLUJO)
    if (!sock.authState.creds.registered) {
        if (!BOT_NUMBER) {
            console.error("❌ Error: No se encontró el número del BOT en el archivo .env");
            process.exit(1);
        }
        setTimeout(async () => {
            try {
                let code = await sock.requestPairingCode(BOT_NUMBER);
                console.log(`\n============================================`);
                console.log(`PASO 1: VINCULACIÓN DEL BOT`);
                console.log(`TU CÓDIGO ES: ${code}`);
                console.log(`Ve a WhatsApp > Dispositivos vinculados > Vincular con código`);
                console.log(`============================================\n`);
            } catch (err) {
                console.error("Error al solicitar código:", err);
            }
        }, 5000);
    }

    sock.ev.on('creds.update', saveCreds);

    // 3. MONITOR DE CONEXIÓN (DISPARADOR DEL PASO 2)
    sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect } = update;
        
        if (connection === 'open') {
            console.log('\n✅ ¡BOT CONECTADO EXITOSAMENTE!');
            console.log(`--------------------------------------------`);
            console.log(`PASO 2: CONFIGURACIÓN DEL DUEÑO`);
            console.log(`El sistema está listo. Por favor, asegúrate de que`);
            console.log(`el número del DUEÑO en el archivo .env sea correcto.`);
            console.log(`Envía el mensaje 'ACTIVAR' desde el celular del dueño.`);
            console.log(`--------------------------------------------\n`);
        }

        if (connection === 'close') {
            const shouldReconnect = (lastDisconnect.error instanceof Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
            if (shouldReconnect) startBot();
        }
    });

    // 4. LÓGICA DE MENSAJES Y CAPTURA DE ID DEL DUEÑO
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;

        const sender = m.key.remoteJid;
        const text = m.message.conversation || m.message.extendedTextMessage?.text || "";

        // Verificamos si el número coincide con el RAW_NUMBER del .env para capturar el JID real
        const OWNER_RAW = process.env.OWNER_RAW_NUMBER;

        if (text.toUpperCase() === "ACTIVAR" && sender.includes(OWNER_RAW)) {
            // Guardamos el JID técnico (con @s.whatsapp.net) para uso futuro
            fs.appendFileSync('.env', `\nOWNER_JID=${sender}`);
            await sock.sendMessage(sender, { text: "✅ ¡IDENTIDAD CONFIRMADA! Ahora soy tu asistente oficial." });
            return;
        }

        // RESPUESTA DE IA (SOLO SI EL BOT YA ESTÁ VINCULADO)
        try {
            const response = await ollama.chat({
                model: 'llama3.2:1b',
                messages: [{ role: 'user', content: text }],
            });
            await sock.sendMessage(sender, { text: response.message.content });
        } catch (error) {
            // Silencioso si la IA aún está cargando
        }
    });
}

startBot();
