#!/usr/bin/env python3
"""
Microservicio para espejo MQTT TTS
Escucha en un tópico interno y republica en el tópico de espejo
"""
import paho.mqtt.client as mqtt
import os
import logging
import time
import json

# Configuración
MQTT_HOST = os.getenv('MQTT_HOST', 'mqtt')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
TOPIC_SOURCE = os.getenv('MQTT_TOPIC_SOURCE', 'moxie/internal/tts')
TOPIC_MIRROR = os.getenv('MQTT_TOPIC_MIRROR', 'moxie/tts/text')
MAX_CHUNK_SIZE = int(os.getenv('MAX_CHUNK_SIZE', '400'))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TTSMirrorService:
    def __init__(self):
        self.client = mqtt.Client(client_id="mqtt_tts_mirror_service")
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        self.startup_sent = False
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info(f"Conectado a MQTT {MQTT_HOST}:{MQTT_PORT}")
            client.subscribe(TOPIC_SOURCE, qos=1)
            logger.info(f"Suscrito a: {TOPIC_SOURCE}")
            
            # Enviar mensaje de inicio
            if not self.startup_sent:
                self.publish_mirror("OK ES-MQTT")
                self.startup_sent = True
        else:
            logger.error(f"Error conectando: {rc}")
    
    def on_disconnect(self, client, userdata, rc):
        logger.warning(f"Desconectado: {rc}")
    
    def on_message(self, client, userdata, msg):
        try:
            # Decodificar mensaje
            if msg.topic == TOPIC_SOURCE:
                text = msg.payload.decode('utf-8').strip()
                if text:
                    logger.info(f"Espejando: {text[:50]}...")
                    self.publish_mirror(text)
        except Exception as e:
            logger.error(f"Error procesando mensaje: {e}")
    
    def split_text(self, text):
        """Dividir texto en chunks"""
        if len(text) <= MAX_CHUNK_SIZE:
            return [text]
        
        chunks = []
        words = text.split()
        current = ""
        
        for word in words:
            if len(current) + len(word) + 1 > MAX_CHUNK_SIZE:
                if current:
                    chunks.append(current.strip())
                    current = word
                else:
                    chunks.append(word[:MAX_CHUNK_SIZE])
                    current = word[MAX_CHUNK_SIZE:]
            else:
                current = f"{current} {word}" if current else word
        
        if current:
            chunks.append(current.strip())
        
        return chunks
    
    def publish_mirror(self, text):
        """Publicar en tópico de espejo"""
        chunks = self.split_text(text)
        
        for chunk in chunks:
            try:
                result = self.client.publish(TOPIC_MIRROR, chunk, qos=1)
                if result.rc != mqtt.MQTT_ERR_SUCCESS:
                    logger.warning(f"Error publicando chunk: {result.rc}")
                else:
                    logger.debug(f"Chunk publicado: {chunk[:30]}...")
                time.sleep(0.05)  # Pausa entre chunks
            except Exception as e:
                logger.error(f"Error publicando: {e}")
    
    def run(self):
        logger.info("Iniciando servicio de espejo MQTT TTS")
        logger.info(f"Fuente: {TOPIC_SOURCE} -> Espejo: {TOPIC_MIRROR}")
        
        try:
            self.client.connect(MQTT_HOST, MQTT_PORT, 60)
            self.client.loop_forever()
        except Exception as e:
            logger.error(f"Error en servicio: {e}")
            return 1
        
        return 0

if __name__ == '__main__':
    service = TTSMirrorService()
    exit(service.run())
