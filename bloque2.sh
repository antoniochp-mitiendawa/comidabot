#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 2: VINCULACIÓN, DUEÑO Y FILTRO GRUPOS
# PROYECTO: COMIDABOT - INSTALACIÓN DESDE CERO
# ==========================================

echo -e "\n\e[1;32m[+] Iniciando FASE DE VINCULACIÓN (Bloque 2)...\e[0m"

cd $HOME/comidabot

# 1. Crear archivo de configuración inicial
cat <<EOT > config.json
{
  "botNumber": "",
  "ownerNumber": "",
  "ownerJID": "",
  "isConfigured": false
}
EOT

# 2. Generar el script de conexión index.js
cat <<EOT > index.js
const { default: makeWASocket, useMultiFileAuthState, fetchLatestBaileysVersion } = require("@whiskeysockets/baileys");
const pino = require("pino");
const fs = require("fs");
const readline = require("readline");

// Interfaz protegida
const rl = readline.createInterface({ 
    input: process.stdin, 
    output: process.stdout,
    terminal: true 
});

const question = (text) => new Promise((resolve) => rl.question(text, resolve));

async function iniciarBot() {
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
    const { version } = await fetchLatestBaileysVersion();

    const sock = makeWASocket({
        version,
        auth: state,
        printQRInTerminal: false,
        logger: pino({ level: "silent" }),
        browser: ["Ubuntu", "Chrome", "20.0.04"]
    });

    // PASO 1: NÚMERO DEL BOT
    if (!sock.authState.creds.registered) {
        console.log("\n\x1b[1;32m--- VINCULACIÓN DE WHATSAPP ---\x1b[0m");
        const numeroBot = await question("\x1b[1;34m[?] Introduce el número del BOT (ej: 521XXXXXXXXXX): \x1b[0m");
        
        try {
            const codigo = await sock.requestPairingCode(numeroBot.trim());
            console.log("\n\x1b[1;33m[!] TU CÓDIGO DE VINCULACIÓN ES:\x1b[0m \x1b[1;32m" + codigo + "\x1b[0m");
            console.log("\x1b[1;36m[i] Ingrésalo en tu WhatsApp.\x1b[0m\n");
        } catch (e) {
            console.log("\x1b[1;31m[!] Error al generar código.\x1b[0m");
            process.exit(1);
        }
    }

    sock.ev.on("creds.update", saveCreds);

    sock.ev.on("connection.update", async (update) => {
        const { connection } = update;
        if (connection === "open") {
            console.log("\n\x1b[1;32m[✔] ¡BOT CONECTADO!\x1b[0m");
            const numDueño = await question("\x1b[1;34m[?] Introduce el número del DUEÑO (ej: 521XXXXXXXXXX): \x1b[0m");
            let config = JSON.parse(fs.readFileSync("./config.json"));
            config.ownerNumber = numDueño.trim();
            fs.writeFileSync("./config.json", JSON.stringify(config, null, 2));
            console.log("\n\x1b[1;33m[!] PASO FINAL:\x1b[0m Envía 'CONFIGURAR' al BOT desde ese número.");
        }
    });

    sock.ev.on("messages.upsert", async (m) => {
        const msg = m.messages[0];
        if (!msg.message || msg.key.fromMe || msg.key.remoteJid.endsWith("@g.us")) return;

        const jidRemoto = msg.key.remoteJid;
        const texto = (msg.message.conversation || msg.message.extendedTextMessage?.text || "").toUpperCase();
        let config = JSON.parse(fs.readFileSync("./config.json"));

        if (texto === "CONFIGURAR" && !config.isConfigured && jidRemoto.includes(config.ownerNumber)) {
            config.ownerJID = jidRemoto;
            config.isConfigured = true;
            fs.writeFileSync("./config.json", JSON.stringify(config, null, 2));
            await sock.sendMessage(jidRemoto, { text: "✅ ID DUEÑO REGISTRADO: " + jidRemoto });
            console.log("\n\x1b[1;32m[✔] PROCESO COMPLETADO.\x1b[0m");
        }
    });
}

iniciarBot();
EOT

# 3. LANZAMIENTO SEGURO (Aquí estaba el fallo)
# Usamos </dev/tty para obligar a Node a leer el teclado real del teléfono
echo -e "\e[1;32m[+] Ejecutando Motor de Conexión...\e[0m"
node index.js </dev/tty
