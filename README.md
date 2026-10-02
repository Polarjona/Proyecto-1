# Stumble Guys — Prototipo

Prototipo de carrera de obstáculos en 3D estilo _Stumble Guys / Fall Guys_, hecho con **Godot Engine 4.7** (Forward Plus) y **GDScript**, con física **Jolt**.

## Cómo ejecutar

1. Abre Godot 4.7 e importa la carpeta `proyecto/` (el archivo `project.godot`).
2. Pulsa **Play (F5)**.

## Generar un ejecutable

El proyecto incluye `proyecto/export_presets.cfg` con presets de _release_ para **Linux** y **Windows** (x86_64), ambos con el PCK incrustado, así que cada build es **un único archivo autocontenido**. Requiere las _export templates_ de Godot 4.7.2 instaladas.

```bash
godot --headless --path proyecto --export-release "Linux" exports/linux/StumbleGuys.x86_64
godot --headless --path proyecto --export-release "Windows Desktop" exports/windows/StumbleGuys.exe
```

Los artefactos quedan en `proyecto/exports/` (excluido de Git).

## Controles

| Acción  | Teclado   | Alternativo |
| ------- | --------- | ----------- |
| Moverse | `W A S D` | Flechas     |
| Saltar  | `Espacio` | —           |
| Pausa   | `Escape`  | —           |

## Características

- **Menú principal** con inicio, controles, créditos y récord guardado.
- **Menú de pausa** (`Escape`): continuar, reiniciar o volver al menú.
- **Carrera cronometrada** con 3 zonas de obstáculos:
  - Cinta transportadora (empuje lateral)
  - Péndulo oscilante (martillo que te lanza)
  - Plataforma giratoria (equilibrio)
- **3 checkpoints** con respawn y penalización (+2.5 s por caída).
- **Persistencia del récord** en `user://best_time.save`.
- **HUD** con tiempo, contador de checkpoints y récord.
- **Audio incluido** (música en bucle + 4 SFX generados con `tools/generate_audio.py`) con degradación elegante si faltan archivos.
- **Animaciones procedurales** del personaje (idle/carrera/salto con squash & stretch).
- **Partículas** en checkpoints y meta, y **transiciones con fade** entre escenas.

## Estructura

```
proyecto/
├── audio/                  # Música y SFX incluidos (generados)
├── materials/              # StandardMaterial3D de colores
├── scenes/
│   ├── main.tscn           # Escena de juego (curso + player + HUD + pausa)
│   ├── menu/               # main_menu.tscn, pause_menu.tscn
│   ├── obstacles/          # conveyor, pendulum, spinning_platform, wall
│   ├── player/player.tscn
│   ├── race/               # checkpoint, finish_line, hud, kill_plane
│   └── ui/                 # (reservada para UI adicional)
├── exports/                # Builds generados (excluido de Git)
├── scripts/                # Un script por responsabilidad + autoloads
└── tools/                  # Scripts auxiliares (tests headless + generador de audio)
```

## Arquitectura

- **Autoloads:** `AudioManager` (música + SFX con pool) y `TransitionManager` (fades).
- **Signals:** `RaceManager` emite `time_updated`, `checkpoint_reached`, `finished`,
  `respawned`, `best_time_updated`, `checkpoints_updated`; el HUD se suscribe.
- **Groups:** `player`, `race_manager`, `pause_menu`, `checkpoints` — para localizar
  nodos sin acoplamiento directo.

## Documentación

- `documentacion/Primera_entrega.md` — Informe de seguimiento de la primera entrega.

## Créditos

- Autores: **Pol Arjona** e **Yazan Issa**
- Motor: [Godot Engine](https://godotengine.org) 4.7
- IA usada en el desarrollo (ver informe en `documentacion/`).
