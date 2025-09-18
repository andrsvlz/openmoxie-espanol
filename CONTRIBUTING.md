# Contribuir a OpenMoxie Español

## Cómo Contribuir

1. **Fork** el repositorio
2. **Crea** una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. **Commit** tus cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. **Push** a la rama (`git push origin feature/nueva-funcionalidad`)
5. **Crea** un Pull Request

## Estándares de Código

- **Python**: Seguir PEP 8
- **JavaScript**: Usar ES6+
- **Documentación**: En español
- **Commits**: Mensajes descriptivos en español

## Testing

Antes de enviar un PR:
1. Ejecutar `./scripts/install.sh` en un entorno limpio
2. Verificar que todos los servicios inicien correctamente
3. Probar Puppet Mode y TTS local
4. Verificar que no hay errores en logs

## Reportar Bugs

Usar GitHub Issues con:
- Descripción clara del problema
- Pasos para reproducir
- Logs relevantes
- Información del sistema
