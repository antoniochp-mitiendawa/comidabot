const { 
    default: makeWASocket, 
    useMultiFileAuthState, 
    fetchLatestBaileysVersion, 
    makeCacheableSignalKeyStore 
} = require("@whiskeysockets/baileys");
const pino = require("pino");
const readline = require("readline");

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (text) => new Promise((resolve) => rl.question(text, resolve));

async function iniciarBot() {
    // Carpeta de sesión
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
    const { version } = await fetchLatestBaileysVersion();

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

    // Proceso de Vinculación
    if (!sock.authState.creds.registered) {
        console.log("\n--- CONFIGURACION DE VINCULACION ---");
        const numeroInput = await question('Introduce tu número de WhatsApp (solo números): ');
        
        const numeroLimpio = numeroInput.replace(/[^0-9]/g, '');
        
        try {
            const codigo = await sock.requestPairingCode(numeroLimpio);
            console.log("\n------------------------------------");
            console.log("TU CODIGO DE VINCULACION ES:");
            console.log(codigo); 
            console.log("------------------------------------\n");
        } catch (error) {
            console.log("Error al solicitar el código: ", error);
        }
    }

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect } = update;
        if (connection === 'close') {
            const debeReintentar = (lastDisconnect?.error?.output?.statusCode !== 401);
            if (debeReintentar) {
                iniciarBot();
            }
        } else if (connection === 'open') {
            console.log("\n[!] BOT CONECTADO EXITOSAMENTE\n");
        }
    });

    sock.ev.on('messages.upsert', async ({ messages }) => {
        const m = messages[0];
        if (!m.message || m.key.fromMe) return;
        const texto = m.message.conversation || m.message.extendedTextMessage?.text || "";
        const idCliente = m.key.remoteJid;

        if (texto.toLowerCase() === 'hola') {
            await sock.sendMessage(idCliente, { text: "¡Hola! Bienvenido." });
        }
    });
}

iniciarBot();
