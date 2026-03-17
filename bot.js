const { makeWASocket, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const fs = require('fs');
const sqlite3 = require('sqlite3').verbose();
const vosk = require('vosk');
const ffmpeg = require('fluent-ffmpeg');

const config = JSON.parse(fs.readFileSync('config.json'));
const db = new sqlite3.Database('comida.db');
const modelo = new vosk.Model('modelo-voz');

function limpiarNumero(n) {
  let l = n.replace(/\D/g, '');
  if (l.startsWith('521')) l = l.slice(3);
  if (l.startsWith('52')) l = l.slice(2);
  return l.slice(0,10);
}

function saludo() {
  const h = new Date().getHours();
  return h < 12 ? '☀️ BUENOS DÍAS' : h < 19 ? '🌤️ BUENAS TARDES' : '🌙 BUENAS NOCHES';
}

async function conectar() {
  const { state, saveCreds } = await useMultiFileAuthState('auth_info');
  const sock = makeWASocket({ auth: state });
  
  sock.ev.on('creds.update', saveCreds);
  
  sock.ev.on('messages.upsert', async ({ messages }) => {
    const m = messages[0];
    if (!m.message) return;
    
    const remitente = limpiarNumero(m.key.remoteJid);
    const esDueña = remitente === config.dueña;
    
    if (m.message.audioMessage && esDueña) {
      const buffer = await m.message.audioMessage.download();
      const path = `/tmp/audio_${Date.now()}.ogg`;
      fs.writeFileSync(path, buffer);
      
      ffmpeg(path).audioFrequency(16000).audioChannels(1).format('wav').save('/tmp/audio.wav').on('end', () => {
        const audio = fs.readFileSync('/tmp/audio.wav');
        const rec = new vosk.Recognizer({ model: modelo, sampleRate: 16000 });
        if (rec.acceptWaveform(audio)) {
          const texto = JSON.parse(rec.result()).text;
          fs.unlinkSync(path);
          fs.unlinkSync('/tmp/audio.wav');
          
          if (texto.includes('activa domicilio')) {
            const tel = texto.match(/\d{10}/)?.[0];
            if (tel) {
              db.run('INSERT INTO domicilio (activo, telefono) VALUES (1, ?)', [tel]);
              sock.sendMessage(m.key.remoteJid, { text: '✅ Domicilio activado' });
            }
          }
          else if (texto.includes('desactiva domicilio')) {
            db.run('UPDATE domicilio SET activo = 0');
            sock.sendMessage(m.key.remoteJid, { text: '✅ Domicilio desactivado' });
          }
          else if (texto.includes('precio')) {
            const p = texto.match(/\d+/)?.[0];
            if (p) {
              db.run('INSERT INTO precio_comida (precio) VALUES (?)', [p]);
              sock.sendMessage(m.key.remoteJid, { text: `✅ Precio: $${p}` });
            }
          }
          else {
            sock.sendMessage(m.key.remoteJid, { text: '✅ Recibido' });
          }
        }
      });
    }
    
    if (m.message.conversation) {
      const txt = m.message.conversation.toLowerCase();
      
      if (txt === 'sí' || txt === 'si') {
        db.get('SELECT activo, telefono FROM domicilio WHERE activo = 1', [], (e, r) => {
          if (r) {
            sock.sendMessage(m.key.remoteJid, { text: '👍 Te llamamos' });
            sock.sendMessage(r.telefono + '@s.whatsapp.net', { 
              text: `🚚 DOMICILIO\nCliente: ${remitente}\nLlama al: ${remitente}` 
            });
          }
        });
        return;
      }
      
      let resp = `${saludo()}\n\n`;
      
      if (new Date().getHours() < 12) {
        db.all('SELECT nombre, precio FROM desayunos WHERE disponible = 1', [], (e, r) => {
          if (r?.length) {
            resp += '🍳 DESAYUNOS\n';
            r.forEach(p => resp += `• ${p.nombre} $${p.precio}\n`);
          }
          resp += `\n🕒 ${config.horario}\n📍 ${config.direccion}`;
          sock.sendMessage(m.key.remoteJid, { text: resp });
        });
      } else {
        db.get('SELECT precio FROM precio_comida ORDER BY rowid DESC', [], (e, pr) => {
          if (pr) resp += `Comida: $${pr.precio}\n\n`;
          db.all('SELECT nombre FROM primer_tiempo WHERE disponible = 1', [], (e1, r1) => {
            if (r1?.length) {
              resp += '🥣 PRIMER TIEMPO\n';
              r1.forEach(p => resp += `• ${p.nombre}\n`);
              resp += '\n';
            }
            db.all('SELECT nombre FROM segundo_tiempo WHERE disponible = 1', [], (e2, r2) => {
              if (r2?.length) {
                resp += '🍚 SEGUNDO TIEMPO\n';
                r2.forEach(p => resp += `• ${p.nombre}\n`);
                resp += '\n';
              }
              db.all('SELECT nombre FROM tercer_tiempo WHERE disponible = 1', [], (e3, r3) => {
                if (r3?.length) {
                  resp += '🍖 TERCER TIEMPO\n';
                  r3.forEach(p => resp += `• ${p.nombre}\n`);
                  resp += '\n';
                }
                db.all('SELECT nombre FROM bebida WHERE disponible = 1', [], (e4, r4) => {
                  if (r4?.length) {
                    resp += '🥤 BEBIDA\n';
                    r4.forEach(p => resp += `• ${p.nombre}\n`);
                    resp += '\n';
                  }
                  db.all('SELECT nombre FROM postre WHERE disponible = 1', [], (e5, r5) => {
                    if (r5?.length) {
                      resp += '🍨 POSTRE\n';
                      r5.forEach(p => resp += `• ${p.nombre}\n`);
                      resp += '\n';
                    }
                    db.get('SELECT activo FROM domicilio WHERE activo = 1', [], (e6, r6) => {
                      resp += `🕒 ${config.horario}\n📍 ${config.direccion}`;
                      if (r6) resp += '\n\n🚚 ¿Domicilio? Responde SÍ';
                      sock.sendMessage(m.key.remoteJid, { text: resp });
                    });
                  });
                });
              });
            });
          });
        });
      }
    }
  });
}

conectar();
