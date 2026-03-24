const { 
    default: makeWASocket, 
    useMultiFileAuthState, 
    fetchLatestBaileysVersion, 
    makeCacheableSignalKeyStore 
} = require("@whiskeysockets/baileys");
const pino = require("pino");
const { readlineInterface } = require("readline");
const question = (text) => new Promise((resolve) => rl.question(text, resolve));
const rl = require("readline").createInterface({ input: process.stdin, output: process.stdout });

async function iniciarBot() {
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
    const { version } = await fetchLatestBaileysVersion();

    const sock = makeWASocket({
        version,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false, // Desactivamos QR
        auth: {
            creds: state.creds,
            keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' })),
        },
        browser: ["Ubuntu", "Chrome", "20.0.04"], // Engañamos al sistema para que permita Pairing
    });

    // Lógica de Pairing Code
    if (!sock.authState.creds.registered) {
        const numeroTel = await question('Introduce tu número de WhatsApp (ej: 5215512345678): ');
        const codigo = await sock.requestPairingCode(numeroTel.trim());
        console.log(`\n\e[1;32mTU CÓDIGO DE VINCULACIÓN ES:\e[0m \e[1;33m${codigo}\e[0m\n`);
    }

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect } = update;
        if (connection === 'close') {
            console.log("Conexión cerrada, reintentando...");
            iniciarBot();
        } else if (connection === 'open') {
            console.log("\n[!] Bot conectado exitosamente a WhatsApp.\n");
        }
    });

    // Responder a mensajes (Prueba básica)
    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;

        const texto = m.message.conversation || m.message.extendedTextMessage?.text || "";
        const idCliente = m.key.remoteJid;

        // Respuesta básica para confirmar que funciona
        if (texto.toLowerCase() === 'hola') {
            await sock.sendMessage(idCliente, { text: "¡Hola! Bienvenido al bot de Comida Corrida. Pronto verás el menú aquí." });
        }
    });
}

iniciarBot();
