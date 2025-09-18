# 🤖 OpenMoxie Español

**Robot compañero inteligente con soporte completo para español y TTS local**

<p align="center">
  <img src="./site/static/hive/openmoxie_logo.svg" width="200" height="200" alt="OpenMoxie Logo">
</p>

OpenMoxie Español es una versión personalizada del proyecto [openmoxie-ollama](https://github.com/moxie-robot/openmoxie-ollama) que incluye:

- ✅ **Configuración automática en español**
- ✅ **TTS local con Piper y voz española**
- ✅ **Mirroring MQTT para reproducción de audio**
- ✅ **Interfaz web completamente funcional**
- ✅ **Soporte para Faster-Whisper multilingüe**
- ✅ **Integración con Ollama para LLM**

---

## 📦 Basado en el increíble trabajo de [jbeghtol/openmoxie](https://github.com/jbeghtol/openmoxie)

---

## ⚠️ Aviso Importante

Este proyecto está diseñado para uso educativo y de desarrollo. El usuario es responsable del contenido generado por los modelos de IA.

---

## 🎯 Características Principales

### 🗣️ **Text-to-Speech Local**
- **Piper TTS** con voz española `es_ES-davefx-medium`
- **Reproducción automática** de todo el texto que Moxie va a decir
- **Monitor web** en tiempo real de mensajes TTS
- **Sin dependencias de servicios externos**

### 🎤 **Speech-to-Text Multilingüe**
- **Faster-Whisper** con modelo `faster-whisper-base`
- **Soporte nativo para español**
- **Procesamiento local** sin envío a la nube
- **Configuración automática** de idioma y modelo

### 🧠 **Inteligencia Artificial**
- **Ollama** con modelos `llama3.1:8b` y `qwen2.5:7b`
- **Respuestas en español** configuradas por defecto
- **Procesamiento local** completo
- **Sin límites de uso**

### 📡 **Comunicación MQTT**
- **Broker MQTT integrado** para comunicación interna
- **TTS Mirroring** automático a topic `moxie/tts/text`
- **Monitoreo en tiempo real** de mensajes
- **Arquitectura escalable** para múltiples servicios

---

## 🚀 Instalación Rápida

### Requisitos Previos

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y docker docker-compose git python3 python3-pip curl

# Verificar instalación
docker --version
docker-compose --version
```

### Instalación Automática

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/openmoxie-espanol.git
cd openmoxie-espanol

# Ejecutar instalación automática
./scripts/install.sh
```

El script de instalación:
1. ✅ Verifica requisitos del sistema
2. ✅ Instala herramientas MQTT
3. ✅ Descarga e instala Piper TTS
4. ✅ Configura servicio TTS local
5. ✅ Construye e inicia servicios Docker
6. ✅ Aplica configuración española
7. ✅ Crea usuario administrador
8. ✅ Verifica funcionamiento completo

---

## 🎮 Uso

### Acceso a la Interfaz Web

```
URL: http://localhost:8000
Usuario: admin
Contraseña: admin123
```

### Puppet Mode (Modo Títere)

1. **Accede** a http://localhost:8000
2. **Inicia sesión** con las credenciales admin/admin123
3. **Navega** a la sección Puppet Mode
4. **Escribe** cualquier texto en español
5. **Envía** el mensaje
6. **Escucha** el audio reproduciéndose automáticamente en tu computador

### Monitor TTS

```
URL: http://localhost:8787
```

Interfaz web que muestra:
- 📨 **Mensajes recibidos** en tiempo real
- 🔊 **Estado de reproducción** de audio
- 📊 **Estadísticas** de uso
- 🔧 **Información del sistema**

---

## 🏗️ Arquitectura

### Componentes

| Componente | Puerto | Descripción |
|------------|--------|-------------|
| **Web Interface** | 8000 | Interfaz principal de Moxie |
| **MQTT Broker** | 1883 | Comunicación entre servicios |
| **Ollama** | 11434 | Servidor de modelos LLM |
| **STT Service** | 8001 | Faster-Whisper para transcripción |
| **TTS Monitor** | 8787 | Monitor web del servicio TTS |

### Flujo de Datos

```
[Interfaz Web] → [Moxie Server] → [MQTT Broker] → [TTS Service] → [Audio Output]
                      ↓
                 [Ollama LLM] ← [Faster-Whisper STT]
```

---

## 🔧 Configuración

### Variables de Entorno

```bash
# Docker Compose
MQTT_HOST=mqtt
OLLAMA_HOST=ollama
STT_HOST=stt

# TTS Local
PIPER_MODEL=es_ES-davefx-medium
AUDIO_DEVICE=default
```

### Configuración Avanzada

#### Cambiar Voz TTS

```bash
# Descargar otra voz española
cd services/moxie-tts-subscriber/piper
curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx" -o nueva-voz.onnx
curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx.json" -o nueva-voz.onnx.json

# Actualizar configuración en services/moxie-tts-subscriber/app.py
PIPER_MODEL = "nueva-voz.onnx"
```

#### Cambiar Modelo STT

```bash
# Editar site/hive/models.py
stt_model = "/models/faster-whisper-large-v2"  # Modelo más preciso
```

---

## 🐛 Troubleshooting

### Problemas Comunes

#### No se escucha audio

```bash
# Verificar servicio TTS
systemctl --user status moxie-tts.service

# Ver logs
journalctl --user -u moxie-tts.service -f

# Reiniciar servicio
systemctl --user restart moxie-tts.service
```

#### Error de conexión MQTT

```bash
# Verificar broker MQTT
docker compose logs mqtt

# Probar conexión
mosquitto_pub -h localhost -p 1883 -t "test" -m "hello"
```

#### Servicios Docker no inician

```bash
# Ver logs de todos los servicios
docker compose logs

# Reconstruir imágenes
docker compose build --no-cache
docker compose up -d
```

### Logs Útiles

```bash
# Logs del servicio web
docker compose logs web -f

# Logs del servicio TTS
journalctl --user -u moxie-tts.service -f

# Logs de MQTT
docker compose logs mqtt -f

# Logs de Ollama
docker compose logs ollama -f
```

---

## 🤝 Contribuir

1. **Fork** el repositorio
2. **Crea** una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. **Commit** tus cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. **Push** a la rama (`git push origin feature/nueva-funcionalidad`)
5. **Crea** un Pull Request

---

## 📄 Licencia

Este proyecto está basado en [openmoxie-ollama](https://github.com/moxie-robot/openmoxie-ollama) y mantiene la misma licencia.

---

## 🙏 Agradecimientos

- **Moxie Robot Team** por el proyecto original
- **Rhasspy Team** por Piper TTS
- **Systran Team** por Faster-Whisper
- **Ollama Team** por el servidor LLM local

---

## 📞 Soporte

- **Issues**: [GitHub Issues](https://github.com/tu-usuario/openmoxie-espanol/issues)
- **Documentación**: [Wiki del proyecto](https://github.com/tu-usuario/openmoxie-espanol/wiki)
- **Discusiones**: [GitHub Discussions](https://github.com/tu-usuario/openmoxie-espanol/discussions)

---

**¡Disfruta de Moxie hablando en español! 🤖🇪🇸**
