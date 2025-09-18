# Generated manually for Spanish configuration
from django.db import migrations
from django.contrib.auth import get_user_model

def configurar_espanol(apps, schema_editor):
    """Configura valores por defecto para español"""
    HiveConfiguration = apps.get_model('hive', 'HiveConfiguration')
    
    # Crear o actualizar configuración por defecto
    config, created = HiveConfiguration.objects.get_or_create(
        name='default',
        defaults={
            'stt_backend': 'local',
            'stt_url': 'http://stt:8001/stt',
            'stt_lang': 'es',
            'stt_device': 'auto',
            'stt_model': '/models/faster-whisper-base',
            'stt_compute': 'float16',
        }
    )
    
    if not created:
        # Actualizar configuración existente
        config.stt_backend = 'local'
        config.stt_url = 'http://stt:8001/stt'
        config.stt_lang = 'es'
        config.stt_device = 'auto'
        config.stt_model = '/models/faster-whisper-base'
        config.stt_compute = 'float16'
        config.save()
        print(f"✅ Configuración actualizada para español: {config.name}")
    else:
        print(f"✅ Configuración creada para español: {config.name}")

def crear_admin_espanol(apps, schema_editor):
    """Crea usuario admin por defecto si no existe"""
    User = get_user_model()
    
    if not User.objects.filter(is_superuser=True).exists():
        admin_user = User.objects.create_superuser(
            username='admin',
            email='admin@moxie.local',
            password='admin123'
        )
        print(f"✅ Usuario admin creado: {admin_user.username}")
    else:
        print("ℹ️ Usuario admin ya existe")

def revertir_configuracion(apps, schema_editor):
    """Revierte la configuración a valores originales"""
    HiveConfiguration = apps.get_model('hive', 'HiveConfiguration')
    
    try:
        config = HiveConfiguration.objects.get(name='default')
        config.stt_backend = 'openai'
        config.stt_url = 'http://127.0.0.1:8001/stt'
        config.stt_lang = 'en'
        config.stt_device = 'auto'
        config.stt_model = ''
        config.stt_compute = 'int8'
        config.save()
        print("⏪ Configuración revertida a valores originales")
    except HiveConfiguration.DoesNotExist:
        pass

class Migration(migrations.Migration):

    dependencies = [
        ('hive', '0021_hiveconfiguration_stt_model'),
    ]

    operations = [
        migrations.RunPython(configurar_espanol, revertir_configuracion),
        migrations.RunPython(crear_admin_espanol, migrations.RunPython.noop),
    ]
