#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# BLOQUE 2: VINCULACIÓN Y REGISTRO DE DUEÑO
# PROYECTO: COMIDABOT - INSTALACIÓN DESDE CERO
# ==========================================

echo -e "\n\e[1;32m[+] Iniciando FASE DE VINCULACIÓN (Bloque 2)...\e[0m"

# Asegurar que estamos en la carpeta del proyecto
cd $HOME/comidabot

# 1. Crear el archivo de configuración inicial (Base de Datos JSON)
echo -e "\e[1;34m[+] Creando base de datos de configuración...\e[0m"
cat <<EOT > config.json
{
  "botNumber": "",
  "ownerNumber": "",
  "ownerJID": "",
  "isConfigured": false
}
EOT

# 2. Crear el script principal de conexión (index.js)
echo -e "\e[1;34m[+] Generando script de conexión por Pairing Code...\e[0m"
cat <<EOT > index.js
const { default: makeWASocket, useMultiFileAuthState, delay } = require("@whiskeysockets/baileys");
const pino = require("pino");
const fs = require("fs");
const readline = require("readline");

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (text) => new Promise((resolve) => rl.question(text, resolve));

async function iniciarBot() {
    const { state, saveCreds } = await useMultiFileAuthState('sesion_auth');
    const sock = makeWASocket({
        auth: state,
        printQRInTerminal: false,
        logger: pino({ level: "silent" })
    });

    if (!sock.authState.creds.registered) {
        console.log("\n\x1b[1;32m--- VINCULACIÓN DE WHATSAPP ---\x1b[0m");
        const numero = await question("\x1b[1;34m[?] Introduce el número del BOT (con código de país, ej: 521XXXXXXXXXX): \x1b[0m");
        const codigo = await sock.requestPairingCode(numero.trim());
        console.log("\n\x1b[1;33m[!] TU CÓDIGO DE VINCULACIÓN ES:\x1b[0m \x1b[1;32m" + codigo + "\x1b[0m");
        console.log("\x1b[1;36m[i] Ingresa este código en tu WhatsApp (Dispositivos vinculados > Vincular con teléfono).\x1b[0m\n");
    }

    sock.ev.on("creds.update", saveCreds);

    sock.ev.on("connection.update", (update) => {
        const { connection } = update;
        if (connection === "open") {
            console.log("\n\x1b[1;32m[✔] ¡BOT CONECTADO EXITOSAMENTE!\x1b[0m");
            solicitarDueño(sock);
        }
    });

    sock.ev.on("messages.upsert", async (m) => {
        const msg = m.messages[0];
        if (!msg.message || msg.key.fromMe) return;
        const texto = msg.message.conversation || msg.message.extendedTextMessage?.text;
        const jidRemoto = msg.key.remoteJid;

        // Lógica para detectar al dueño por primera vez
        let config = JSON.parse(fs.readFileSync("./config.json"));
        if (texto && texto.toUpperCase() === "CONFIGURAR" && !config.isConfigured) {
            config.ownerJID = jidRemoto;
            config.isConfigured = true;
            fs.writeFileSync("./config.json", JSON.stringify(config, null, 2));
            await sock.sendMessage(jidRemoto, { text: "¡ID EXTRAÍDO! Ahora eres reconocido como el DUEÑO oficial." });
            console.log("\n\x1b[1;32m[✔] DUEÑO REGISTRADO: " + jidRemoto + "\x1b[0m");
        }
    });
}

async function solicitarDueño(sock) {
    let config = JSON.parse(fs.readFileSync("./config.json"));
    if (!config.isConfigured) {
        console.log("\x1b[1;33m[!] ESPERANDO REGISTRO DEL DUEÑO...\x1b[0m");
        console.log("\x1b[1;36m[i] Por favor, envía la palabra 'CONFIGURAR' desde tu número personal al chat del BOT.\x1b[0m");
    }
}

iniciarBot();
EOT

# 3. Ejecutar el bot inmediatamente
echo -e "\e[1;32m[+] Iniciando ejecución del Bot...\e[0m"
node index.js
