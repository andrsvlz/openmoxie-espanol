# Dockerfile para microservicio de espejo MQTT TTS
FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias
RUN pip install --no-cache-dir paho-mqtt

# Copiar script del microservicio
COPY mqtt-tts-mirror-service.py /app/

# Usuario no-root
RUN useradd -m -u 1000 mqttuser
USER mqttuser

CMD ["python", "mqtt-tts-mirror-service.py"]
