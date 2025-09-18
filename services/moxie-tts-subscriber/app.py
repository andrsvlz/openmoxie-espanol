#!/usr/bin/env python3
"""
Servicio suscriptor MQTT para reproducir texto TTS de Moxie con Piper
"""
import paho.mqtt.client as mqtt
import subprocess
import tempfile
import os
import logging
import time
import threading
import queue
from datetime import datetime
from flask import Flask, render_template_string
from waitress import serve
import json

# Configuración desde variables de entorno
MQTT_HOST = os.getenv('MQTT_HOST', 'localhost')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
MQTT_TOPIC = os.getenv('MQTT_TOPIC', 'moxie/tts/text')
PIPER_BIN = os.getenv('PIPER_BIN', '/home/steve/piper/piper')
PIPER_MODEL = os.getenv('PIPER_MODEL', '/home/steve/piper/es_ES-vera-medium.onnx')
PIPER_CONF = os.getenv('PIPER_CONF', '/home/steve/piper/es_ES-vera-medium.onnx.json')
HTTP_PORT = int(os.getenv('HTTP_PORT', '8787'))

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Cola para mensajes recibidos y historial
message_queue = queue.Queue()
message_history = []
history_lock = threading.Lock()

class TTSPlayer:
    """Reproductor TTS usando Piper"""
    
    def __init__(self):
        self.playing = False
        self.play_lock = threading.Lock()
        
    def play_text(self, text: str):
        """Reproducir texto usando Piper TTS"""
        if not text.strip():
            return
            
        with self.play_lock:
            try:
                self.playing = True
                logger.info(f"🔊 Reproduciendo: {text}")
                
                # Verificar que Piper existe
                if not os.path.exists(PIPER_BIN):
                    logger.error(f"Piper no encontrado en: {PIPER_BIN}")
                    return
                    
                if not os.path.exists(PIPER_MODEL):
                    logger.error(f"Modelo Piper no encontrado en: {PIPER_MODEL}")
                    return
                
                # Crear archivo temporal para el audio
                with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_audio:
                    audio_file = tmp_audio.name
                
                try:
                    # Ejecutar Piper para generar audio
                    cmd = [
                        PIPER_BIN,
                        '--model', PIPER_MODEL,
                        '--output_file', audio_file
                    ]
                    
                    # Agregar archivo de configuración si existe
                    if os.path.exists(PIPER_CONF):
                        cmd.extend(['--config', PIPER_CONF])
                    
                    logger.debug(f"Ejecutando: {' '.join(cmd)}")
                    
                    # Enviar texto a Piper
                    process = subprocess.Popen(
                        cmd,
                        stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        text=True
                    )
                    
                    stdout, stderr = process.communicate(input=text)
                    
                    if process.returncode != 0:
                        logger.error(f"Error en Piper: {stderr}")
                        return
                    
                    # Reproducir audio con aplay/paplay
                    if os.path.exists(audio_file) and os.path.getsize(audio_file) > 0:
                        # Intentar con paplay primero (PulseAudio), luego aplay (ALSA)
                        for player in ['paplay', 'aplay']:
                            try:
                                result = subprocess.run([player, audio_file],
                                                      check=True,
                                                      capture_output=True,
                                                      timeout=30)
                                logger.info(f"✅ Audio reproducido con {player}")
                                break
                            except subprocess.CalledProcessError as e:
                                logger.warning(f"Error con {player}: {e.stderr.decode() if e.stderr else 'Sin detalles'}")
                                continue
                            except FileNotFoundError:
                                logger.warning(f"{player} no encontrado")
                                continue
                            except subprocess.TimeoutExpired:
                                logger.warning(f"Timeout con {player}")
                                continue
                        else:
                            logger.error("❌ No se pudo reproducir audio con ningún reproductor")
                    else:
                        logger.warning("No se generó archivo de audio")
                        
                finally:
                    # Limpiar archivo temporal
                    try:
                        os.unlink(audio_file)
                    except:
                        pass
                        
            except Exception as e:
                logger.error(f"Error reproduciendo TTS: {e}")
            finally:
                self.playing = False

# Instancia global del reproductor
tts_player = TTSPlayer()

def on_connect(client, userdata, flags, rc):
    """Callback de conexión MQTT"""
    if rc == 0:
        logger.info(f"✅ Conectado a MQTT broker {MQTT_HOST}:{MQTT_PORT}")
        client.subscribe(MQTT_TOPIC, qos=1)
        logger.info(f"📡 Suscrito a tópico: {MQTT_TOPIC}")
    else:
        logger.error(f"❌ Error conectando a MQTT: código {rc}")

def on_message(client, userdata, msg):
    """Callback de mensaje MQTT recibido"""
    try:
        text = msg.payload.decode('utf-8').strip()
        if not text:
            return
            
        timestamp = datetime.now()
        logger.info(f"📨 Recibido: {text}")
        
        # Agregar al historial
        with history_lock:
            message_history.append({
                'timestamp': timestamp.isoformat(),
                'text': text,
                'topic': msg.topic
            })
            # Mantener solo los últimos 50 mensajes
            if len(message_history) > 50:
                message_history.pop(0)
        
        # Agregar a la cola para reproducción
        message_queue.put(text)
        
    except Exception as e:
        logger.error(f"Error procesando mensaje: {e}")

def on_disconnect(client, userdata, rc):
    """Callback de desconexión MQTT"""
    if rc != 0:
        logger.warning(f"⚠️ Desconectado inesperadamente del MQTT broker: código {rc}")
    else:
        logger.info("🔌 Desconectado del MQTT broker")

def worker_thread():
    """Hilo trabajador para procesar cola de mensajes"""
    logger.info("🎵 Iniciando hilo reproductor TTS")
    
    while True:
        try:
            # Esperar por mensaje en la cola
            text = message_queue.get(timeout=1)
            
            # Reproducir el texto
            tts_player.play_text(text)
            
            # Marcar tarea como completada
            message_queue.task_done()
            
        except queue.Empty:
            continue
        except Exception as e:
            logger.error(f"Error en hilo trabajador: {e}")

# Aplicación Flask para monitoreo HTTP
app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Moxie TTS Monitor</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .status { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .status.connected { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .status.disconnected { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .message { background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px; padding: 10px; margin: 5px 0; }
        .timestamp { color: #6c757d; font-size: 0.9em; }
        .text { margin: 5px 0; font-weight: bold; }
        .no-messages { text-align: center; color: #6c757d; font-style: italic; padding: 20px; }
        .refresh { text-align: center; margin: 20px 0; }
        .refresh button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
        .refresh button:hover { background: #0056b3; }
    </style>
    <script>
        function refreshPage() { location.reload(); }
        // Auto-refresh cada 10 segundos
        setTimeout(refreshPage, 10000);
    </script>
</head>
<body>
    <div class="container">
        <h1>🤖 Moxie TTS Monitor</h1>
        
        <div class="status {{ 'connected' if connected else 'disconnected' }}">
            Estado: {{ 'Conectado' if connected else 'Desconectado' }} | 
            Tópico: {{ topic }} | 
            Reproduciendo: {{ 'Sí' if playing else 'No' }}
        </div>
        
        <h2>📨 Últimos mensajes ({{ message_count }})</h2>
        
        {% if messages %}
            {% for msg in messages %}
            <div class="message">
                <div class="timestamp">{{ msg.timestamp }}</div>
                <div class="text">{{ msg.text }}</div>
            </div>
            {% endfor %}
        {% else %}
            <div class="no-messages">No hay mensajes recibidos</div>
        {% endif %}
        
        <div class="refresh">
            <button onclick="refreshPage()">🔄 Actualizar</button>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    """Página principal de monitoreo"""
    with history_lock:
        messages = list(reversed(message_history))  # Más recientes primero
    
    return render_template_string(HTML_TEMPLATE,
                                messages=messages,
                                message_count=len(messages),
                                connected=mqtt_client.is_connected() if 'mqtt_client' in globals() else False,
                                playing=tts_player.playing,
                                topic=MQTT_TOPIC)

def main():
    """Función principal"""
    global mqtt_client
    
    logger.info("🚀 Iniciando Moxie TTS Subscriber")
    logger.info(f"📡 MQTT: {MQTT_HOST}:{MQTT_PORT}")
    logger.info(f"🎵 Piper: {PIPER_BIN}")
    logger.info(f"🗣️ Modelo: {PIPER_MODEL}")
    logger.info(f"🌐 HTTP: http://localhost:{HTTP_PORT}")
    
    # Iniciar hilo trabajador
    worker = threading.Thread(target=worker_thread, daemon=True)
    worker.start()
    
    # Configurar cliente MQTT
    mqtt_client = mqtt.Client(client_id="moxie_tts_subscriber")
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.on_disconnect = on_disconnect
    
    # Conectar a MQTT
    try:
        mqtt_client.connect(MQTT_HOST, MQTT_PORT, 60)
        mqtt_client.loop_start()
    except Exception as e:
        logger.error(f"Error conectando a MQTT: {e}")
        return 1
    
    # Iniciar servidor HTTP en hilo separado
    def run_http():
        serve(app, host='0.0.0.0', port=HTTP_PORT, threads=2)
    
    http_thread = threading.Thread(target=run_http, daemon=True)
    http_thread.start()
    
    logger.info("✅ Servicio iniciado. Presiona Ctrl+C para salir.")
    
    try:
        # Mantener el programa corriendo
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("🛑 Deteniendo servicio...")
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
        return 0

if __name__ == '__main__':
    exit(main())
