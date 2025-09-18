"""
Publicador MQTT para espejo de texto TTS
Publica el texto que Moxie va a decir en el tópico moxie/tts/text
"""
import paho.mqtt.client as mqtt
import logging
import threading
import time
from typing import Optional

logger = logging.getLogger(__name__)

class TTSMirrorPublisher:
    """Publicador MQTT para espejo de texto TTS con reconexión automática"""
    
    def __init__(self, 
                 host: str = "localhost", 
                 port: int = 1883, 
                 topic: str = "moxie/tts/text",
                 max_chunk_size: int = 400):
        self.host = host
        self.port = port
        self.topic = topic
        self.max_chunk_size = max_chunk_size
        self.client: Optional[mqtt.Client] = None
        self.connected = False
        self.startup_message_sent = False
        self._lock = threading.Lock()
        
        # Inicializar cliente MQTT
        self._init_client()
        
    def _init_client(self):
        """Inicializar cliente MQTT con configuración de reconexión"""
        try:
            self.client = mqtt.Client(client_id="moxie_tts_mirror", protocol=mqtt.MQTTv311)
            self.client.on_connect = self._on_connect
            self.client.on_disconnect = self._on_disconnect
            self.client.on_log = self._on_log
            
            # Configurar reconexión automática
            self.client.reconnect_delay_set(min_delay=1, max_delay=120)
            
            # Intentar conectar
            self._connect()
            
        except Exception as e:
            logger.warning(f"Error inicializando cliente MQTT TTS Mirror: {e}")
            self.client = None
    
    def _connect(self):
        """Conectar al broker MQTT"""
        if not self.client:
            return
            
        try:
            logger.info(f"Conectando TTS Mirror a MQTT broker {self.host}:{self.port}")
            self.client.connect(self.host, self.port, 60)
            self.client.loop_start()
        except Exception as e:
            logger.warning(f"Error conectando a MQTT broker para TTS Mirror: {e}")
    
    def _on_connect(self, client, userdata, flags, rc):
        """Callback de conexión exitosa"""
        if rc == 0:
            self.connected = True
            logger.info(f"TTS Mirror conectado a MQTT broker {self.host}:{self.port}")
            
            # Enviar mensaje de inicio una sola vez
            if not self.startup_message_sent:
                self._publish_message("OK ES-MQTT")
                self.startup_message_sent = True
        else:
            logger.warning(f"Error conectando TTS Mirror a MQTT: código {rc}")
            self.connected = False
    
    def _on_disconnect(self, client, userdata, rc):
        """Callback de desconexión"""
        self.connected = False
        if rc != 0:
            logger.warning(f"TTS Mirror desconectado inesperadamente del MQTT broker: código {rc}")
        else:
            logger.info("TTS Mirror desconectado del MQTT broker")
    
    def _on_log(self, client, userdata, level, buf):
        """Callback de logs (solo para debug)"""
        # Solo loguear errores para evitar spam
        if level <= mqtt.MQTT_LOG_WARNING:
            logger.debug(f"MQTT TTS Mirror: {buf}")
    
    def _publish_message(self, message: str, qos: int = 1) -> bool:
        """Publicar un mensaje en MQTT"""
        if not self.client or not self.connected:
            logger.debug("TTS Mirror: Cliente MQTT no conectado, saltando publicación")
            return False
        
        try:
            result = self.client.publish(self.topic, message, qos=qos)
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.debug(f"TTS Mirror publicado: {message[:50]}{'...' if len(message) > 50 else ''}")
                return True
            else:
                logger.warning(f"Error publicando TTS Mirror: código {result.rc}")
                return False
        except Exception as e:
            logger.warning(f"Excepción publicando TTS Mirror: {e}")
            return False
    
    def _split_text(self, text: str) -> list[str]:
        """Dividir texto en chunks de máximo max_chunk_size caracteres"""
        if len(text) <= self.max_chunk_size:
            return [text]
        
        chunks = []
        words = text.split()
        current_chunk = ""
        
        for word in words:
            # Si agregar esta palabra excede el límite
            if len(current_chunk) + len(word) + 1 > self.max_chunk_size:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                    current_chunk = word
                else:
                    # Palabra muy larga, dividir por caracteres
                    chunks.append(word[:self.max_chunk_size])
                    current_chunk = word[self.max_chunk_size:]
            else:
                if current_chunk:
                    current_chunk += " " + word
                else:
                    current_chunk = word
        
        if current_chunk:
            chunks.append(current_chunk.strip())
        
        return chunks
    
    def publish_text(self, text: str):
        """
        Publicar texto en el tópico MQTT
        Si el texto es mayor a max_chunk_size, lo divide en múltiples mensajes
        """
        if not text or not text.strip():
            return
        
        text = text.strip()
        
        with self._lock:
            # Si no hay cliente o no está conectado, intentar reconectar
            if not self.client or not self.connected:
                logger.debug("TTS Mirror: Reintentando conexión MQTT")
                self._init_client()
                
                # Esperar un poco para la conexión
                for _ in range(10):  # Máximo 1 segundo
                    if self.connected:
                        break
                    time.sleep(0.1)
            
            # Dividir texto si es necesario
            chunks = self._split_text(text)
            
            # Publicar cada chunk en orden
            for i, chunk in enumerate(chunks):
                success = self._publish_message(chunk)
                if not success:
                    logger.warning(f"Error publicando chunk {i+1}/{len(chunks)} del texto TTS")
                    break
                
                # Pequeña pausa entre chunks para mantener orden
                if i < len(chunks) - 1:
                    time.sleep(0.05)
    
    def close(self):
        """Cerrar conexión MQTT"""
        if self.client:
            try:
                self.client.loop_stop()
                self.client.disconnect()
            except Exception as e:
                logger.warning(f"Error cerrando cliente MQTT TTS Mirror: {e}")
            finally:
                self.client = None
                self.connected = False
