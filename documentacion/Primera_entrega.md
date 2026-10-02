# Informe de Seguiment — Primera Entrega

**Projecte:** Stumble Guys (Prototip)  
**Autors:** Pol Arjona i Yazan Issa
**Motor seleccionat:** Godot Engine 4.7 (Forward Plus)  
**Llenguatge:** GDScript  
**Data:** Setembre 2026

---

## 1. Resum de l'Estat i Avenç

**Percentatge d'Avenç:** ~55% del total del projecte | ~32 hores invertides de les 60 hores estimades.

### Fites Cobertes

- **Fita 1 — Idea i Prototip: COMPLETADA**
  - Definició de la proposta: carrera d'obstacles en 3D estil _Stumble Guys / Fall Guys_.
  - Motor escollit: Godot Engine 4.7 amb física Jolt.
  - Creació del repositori Git amb estructura de carpetes correcta (`proyecto/`, `documentacion/`).
  - Escena principal de joc configurada amb il·luminació, entorn i curs complet.
  - Primers assets: materials de colors en `materials/`.

- **Fita 2 — Core del Projecte: COMPLETADA (mecànica principal)**
  - Mecànica de moviment del jugador completament implementada (moviment 3D, salt, inèrcia, control de càmera).
  - Sistema de carrera amb cronòmetre en temps real.
  - Tres tipus d'obstacles funcionals: cinta transportadora, pèndol i plataforma giratoria.
  - Sistema de checkpoints i respawn.
  - HUD bàsic que mostra el temps i missatges de feedback.
  - Física de Jolt integrada per a resultats més realistes.

- **Fita 3 — UI / UX: COMPLETADA**
  - **Menú principal** (`scenes/menu/main_menu.tscn`): botons d'inici, controls, crèdits i sortir, rècord visible i panells informatius. És l'escena d'arrencada del projecte (`run/main_scene`).
  - **Menú de pausa** (`scenes/menu/pause_menu.tscn`): obert amb `Escape`, amb continuar / reiniciar / menú principal. Fa servir `process_mode = PROCESS_MODE_ALWAYS` i pausa l'arbre amb `get_tree().paused`.
  - **Millores de HUD:** contador de checkpoints completats (`2/3`) i rècord personal visibles durant la carrera.

- **Fita 4 — Persistència, Àudio i Animacions: COMPLETADA**
  - **Persistència:** el millor temps es desa a `user://best_time.save` amb `FileAccess` en creuar la meta i es carrega a l'inici; es mostra al menú principal i al HUD.
  - **Àudio:** `AudioManager` (autoload) amb música en bucle i pool de 6 reproductors per a SFX (salt, checkpoint, meta, caiguda). Comprova l'existència dels fitxers i omet la reproducció si no hi són (degradació elegant). Els fitxers d'àudio ja estan inclosos al repositori, generats des de zero amb `tools/generate_audio.py`.
  - **Animacions:** animacions procedurals del personatge (idle amb bob, carrera amb rebot segons velocitat, salt amb estirament i _squash_ en aterrizar) al `player.gd`.
  - **Transicions de pantalla:** `TransitionManager` (autoload) amb fade a negre entre escenes.
  - **Feedback visual:** ràfega de partícules verdes en activar cada checkpoint, confeti groc en creuar la meta, i animació de "pop" a la barra del checkpoint.

### Objectiu de l'Entrega

El prototip compleix tot el cicle demanat per a la primera entrega: el jugador arrenca des d'un **menú principal**, inicia la carrera amb **transició fade**, corre per les tres zones d'obstacles, activa **checkpoints amb feedback visual i sonor**, pot **pausar** en qualsevol moment, i en arribar a la meta el temps es registra i el **rècord es desa a disc** i es mostra al menú. El nucli jugable (core loop) i tota la capa d'UI/persistència/feedback són funcionals.

---

## 2. Implementació de l'MVP i Funcionalitat Central

### Mecànica Principal

El jugador controla un personatge en 3D des d'una perspectiva de càmera en tercera persona fixa. El curs és lineal i incorpora tres zones d'obstacles seqüencials que el jugador ha de superar per arribar a la meta:

1. **Cinta transportadora** — empeny el jugador lateralment; requereix compensar la força per mantenir la trajectòria.
2. **Pèndol oscil·lant** — un martell que gira i llença el jugador si hi col·lisiona.
3. **Plataforma giratoria** — una plataforma que gira sobre l'eix Y; el jugador ha de mantenir l'equilibri.

**Estat:** Totalment funcional. Les col·lisions, el moviment i les respostes físiques funcionen sense errors greus.

### Flux de Joc Complet

```
Menú principal → INICIAR (fade) → Carrera → [Escape → Pausa] → Meta
                                      ↑                    │
                                      └── Reiniciar ───────┘
                                └── Menú Principal (fade) ─┘
```

### Estructura d'Escenes

| Escena                                    | Estat        | Descripció                                                                     |
| ----------------------------------------- | ------------ | ------------------------------------------------------------------------------ |
| `scenes/menu/main_menu.tscn`              | ✅ Operativa | Menú principal: iniciar, controls, crèdits, sortir, rècord                     |
| `scenes/menu/pause_menu.tscn`             | ✅ Operativa | Menú de pausa (CanvasLayer): continuar, reiniciar, menú                        |
| `scenes/main.tscn`                        | ✅ Operativa | Escena principal de joc: curs, jugador, obstacles, HUD, RaceManager, PauseMenu |
| `scenes/player/player.tscn`               | ✅ Operativa | Personatge jugable amb CharacterBody3D i animació procedural                   |
| `scenes/obstacles/conveyor.tscn`          | ✅ Operativa | Cinta transportadora (Area3D)                                                  |
| `scenes/obstacles/pendulum.tscn`          | ✅ Operativa | Pèndol amb AnimatableBody3D                                                    |
| `scenes/obstacles/spinning_platform.tscn` | ✅ Operativa | Plataforma rotatoria                                                           |
| `scenes/obstacles/wall.tscn`              | ✅ Operativa | Paret estàtica de límit                                                        |
| `scenes/race/checkpoint.tscn`             | ✅ Operativa | Punt de control (Area3D) amb partícules one-shot                               |
| `scenes/race/finish_line.tscn`            | ✅ Operativa | Línia de meta (Area3D) amb confeti                                             |
| `scenes/race/hud.tscn`                    | ✅ Operativa | HUD: temps, checkpoints, rècord i missatges                                    |
| `scenes/race/kill_plane.tscn`             | ✅ Operativa | Pla invisible que detecta caigudes                                             |

> **Nota:** la carpeta `scenes/ui/` queda reservada per a UI addicional. Les transicions de pantalla es fan amb l'autoload `TransitionManager` (no requereix escena pròpia).

### Com Executar el Projecte

1. Obrir **Godot Engine 4.7** i importar la carpeta `proyecto/` (fitxer `proyecto/project.godot`).
2. Prémer **Play (F5)**. L'escena d'arrencada és `scenes/menu/main_menu.tscn`.
3. No cal cap pas manual previ: en obrir el projecte, Godot importa automàticament l'escena, els materials i els fitxers d'àudio.

### Controls i Interacció

| Acció              | Teclat   | Teclat alternatiu   |
| ------------------ | -------- | ------------------- |
| Moure endavant     | `W`      | ↑ (fletxa amunt)    |
| Moure enrere       | `S`      | ↓ (fletxa avall)    |
| Moure esquerra     | `A`      | ← (fletxa esquerra) |
| Moure dreta        | `D`      | → (fletxa dreta)    |
| Saltar             | `Espai`  | —                   |
| Pausar / Reprendre | `Escape` | —                   |

Els controls estan mapejats a través del sistema d'`InputMap` de Godot al fitxer `project.godot` (inclosa l'acció `pause`).

---

## 3. Qualitat Tècnica i Estructures Bàsiques

### Qualitat del Codi

El codi segueix un disseny modular basat en scripts independents, cadascun amb una única responsabilitat clara:

| Script                  | Responsabilitat                                                                        |
| ----------------------- | -------------------------------------------------------------------------------------- |
| `player.gd`             | Moviment, salt, gravetat, càmera, respawn, animació procedural, SFX de salt            |
| `race_manager.gd`       | Cronòmetre, checkpoints, estat de la carrera, pausa, persistència del rècord, senyals  |
| `hud.gd`                | Mostra temps, checkpoints, rècord i missatges; subscriu-se als senyals del RaceManager |
| `checkpoint.gd`         | Detectar pas del jugador, notificar al RaceManager, feedback (partícules + pop + SFX)  |
| `finish_line.gd`        | Detectar arribada a meta, notificar al RaceManager, confeti + SFX                      |
| `kill_plane.gd`         | Detectar caiguda, SFX de caiguda, activar respawn                                      |
| `conveyor.gd`           | Aplicar velocitat de cinta als cossos que hi estan a sobre                             |
| `pendulum.gd`           | Moviment sinusoïdal del martell, aplicar impulsos al jugador                           |
| `spinning_platform.gd`  | Rotació constant sobre l'eix Y                                                         |
| `main_menu.gd`          | Navegació del menú principal, càrrega del rècord, transició a la carrera               |
| `pause_menu.gd`         | Grup `pause_menu`, continuar/reiniciar/sortir amb transicions                          |
| `audio_manager.gd`      | **Autoload.** Música en bucle + pool de SFX amb fallback si falten fitxers             |
| `transition_manager.gd` | **Autoload.** Fade a negre i canvi de escena (`change_scene(path)`)                    |

**Bones pràctiques aplicades:**

- Variables i funcions amb noms descriptius en anglès.
- Comentaris de documentació amb `##` en les classes i funcions clau.
- Cap codi duplicat: els obstacles comparteixen la interfície `apply_push()` del jugador.
- Comunicació desacoblada via senyals de Godot (`signal`): `time_updated`, `checkpoint_reached`, `finished`, `respawned`, `best_time_updated`, `checkpoints_updated`.
- Ús de grups de Godot (`add_to_group`) per localitzar nodes sense dependències directes: `player`, `race_manager`, `pause_menu`, `checkpoints`.
- Autoloads per a serveis globals (àudio i transicions) en comptes de singletons duplicats per escena.
- Script de la plataforma giratoria usa `AnimatableBody3D` perquè `CharacterBody3D` pugui cavalcar-hi correctament via `move_and_slide`.
- Gestió d'errors a la persistència (`FileAccess.file_exists`, comprovació de null) i a l'àudio (`ResourceLoader.exists`).

### Control de Versions (Git)

- Repositori local actiu a la carpeta del projecte.
- S'utilitza l'estructura de carpetes requerida: `proyecto/`, `documentacion/`, `README.md`.
- Afegit **`.gitignore`** a l'arrel que exclou `proyecto/.godot/` (cau d'editor i shaders compilats), les exportacions (`exports/`) i els binaris d'exportació (`*.exe`, `*.pck`, `*.x86_64`, `*.zip`, etc.).

### Estructura del Repositori

```
.
├── README.md                   # Com executar, controls, característiques i arquitectura
├── .gitignore                  # Exclou .godot/, exports/ i binaris d'exportació
├── documentacion/
│   └── Primera_entrega.md      # Aquest informe de seguiment
└── proyecto/                   # Projecte de Godot (detallat a continuació)
```

### Arbre d'Assets

```
proyecto/
├── icon.svg                    # Icona del projecte (Godot per defecte)
├── project.godot               # Configuració (autoloads, InputMap, escena inicial)
├── audio/                      # Fitxers d'àudio inclosos (generats amb tools/generate_audio.py)
│   ├── music/                  #   background.ogg (música en bucle)
│   └── sfx/                    #   jump.wav, checkpoint.wav, finish.wav, fall.wav
├── materials/                  # Materials de color (StandardMaterial3D)
│   ├── blue.tres, cyan.tres, lime.tres
│   ├── orange.tres, pink.tres
│   ├── purple.tres, yellow.tres
├── scenes/
│   ├── main.tscn               # Escena principal de joc (inclou PauseMenu)
│   ├── menu/
│   │   ├── main_menu.tscn      # Menú principal
│   │   └── pause_menu.tscn     # Menú de pausa
│   ├── player/player.tscn
│   ├── obstacles/
│   │   ├── conveyor.tscn
│   │   ├── pendulum.tscn
│   │   ├── spinning_platform.tscn
│   │   └── wall.tscn
│   ├── race/
│   │   ├── checkpoint.tscn     # Amb CPUParticles3D one-shot
│   │   ├── finish_line.tscn    # Amb CPUParticles3D de confeti
│   │   ├── hud.tscn            # Temps, checkpoints, rècord, missatges
│   │   └── kill_plane.tscn
│   └── ui/                     # Reservada per a UI addicional
├── scripts/
    ├── player.gd
    ├── race_manager.gd
    ├── hud.gd
    ├── checkpoint.gd
    ├── finish_line.gd
    ├── kill_plane.gd
    ├── conveyor.gd
    ├── pendulum.gd
    ├── spinning_platform.gd
    ├── main_menu.gd
    ├── pause_menu.gd
    ├── audio_manager.gd        # Autoload
    └── transition_manager.gd   # Autoload
└── tools/                      # Scripts auxiliars (verificació i generació d'assets)
    ├── check_scenes.gd         # Valida que les 12 escenes carreguen
    ├── smoke_test.gd           # Executa menú + partida en headless
    ├── flow_test.gd            # Recorre el flux de joc complet en headless
    └── generate_audio.py       # Sintetitza la música en bucle i els 4 SFX
```

**Assets externs:** No hi ha cap asset extern. Materials, geometries i partícules són generats proceduralment per Godot (CSGBox3D, `StandardMaterial3D`, `CPUParticles3D`), i el so (música i 4 SFX) es sintetitza des de zero amb `proyecto/tools/generate_audio.py`, de manera que és lliure de drets i reproducible.

---

## 4. Pròxims Passos i Gestió de Riscos

### Completat a Fita 3 i Fita 4

- ✅ Menú principal com a escena d'arrencada.
- ✅ Pausa amb `Escape` (acció `pause` a l'InputMap, `get_tree().paused`, `PROCESS_MODE_ALWAYS` al menú).
- ✅ Marcador de checkpoints completats al HUD.
- ✅ Persistència del millor temps amb `FileAccess` (`user://best_time.save`).
- ✅ Sistema d'àudio complet (música + 4 SFX) amb degradació elegant.
- ✅ Animacions procedurals idle/carrera/salt amb squash & stretch.
- ✅ Partícules en checkpoints i meta; transicions fade entre escenes.
- ✅ `README.md` complet i `.gitignore`.
- ✅ Build executable per a Linux i Windows (`export_presets.cfg`).

### Build Executable (Feta)

El projecte inclou `proyecto/export_presets.cfg` amb dos presets de _release_ per a **Linux (x86_64)** i **Windows Desktop (x86_64)**, tots dos amb el PCK incrustat (`binary_format/embed_pck=true`), de manera que generen **un únic executable autocontingut** sense cap fitxer adjunt:

| Plataforma     | Fitxer generat                              | Mida   |
| -------------- | ------------------------------------------- | ------ |
| Linux x86_64   | `proyecto/exports/linux/StumbleGuys.x86_64` | 72 MB  |
| Windows x86_64 | `proyecto/exports/windows/StumbleGuys.exe`  | 106 MB |

Es regeneren amb Godot 4.7.2 i les seves _export templates_ instal·lades:

```bash
godot --headless --path proyecto --export-release "Linux" exports/linux/StumbleGuys.x86_64
godot --headless --path proyecto --export-release "Windows Desktop" exports/windows/StumbleGuys.exe
```

Ambdós binaris s'han executat per comprovar que arranquen sense errors i que troben tots els recursos (escenes, materials i àudio). La carpeta `proyecto/exports/` i els binaris d'exportació (`*.exe`, `*.pck`) estan exclosos de Git via `.gitignore`, així que els artefactes s'entreguen a part del repositori.

### Focus Immediat (Fita 6)

- **Vídeo demostratiu:** gravar una partida completa (menú → cursa → pausa → meta) per a l'entrega.
- **Àudio propi (opcional):** substituir els fitxers generats per música/SFX escollits a mà; només cal respectar els noms i rutes que espera l'`AudioManager`.
- **Polit optional:** animació visual pròpia del títol del menú, música diferent per al menú i la cursa.

### Revisió de l'Abast

L'abast actual és realista i tot el que es demanava per a la primera entrega està implementat, inclòs el build executable. L'única tasca pendent (el vídeo demostratiu) és curta i sense risc tècnic.

### Incidències i Desviacions

- **Física de cinta transportadora:** La primera implementació aplicava la força com a `velocity +=` directament, cosa que conflictia amb la fricció del jugador. Solucionat separant la velocitat de cinta (`_belt_velocity`) de la velocitat controlada pel jugador (`_control_velocity`) al `player.gd`, de manera que la cinta no es veu afectada per la fricció.
- **Prioritat de processament del conveyor:** El conveyor cal que processi _abans_ del jugador al mateix frame físic. Solucionat establint `process_physics_priority = -5` al `conveyor.gd`.
- **Càmera penjant:** Inicialment la càmera era filla del node del jugador i girava amb ell. Solucionat posant el pivot de càmera en mode `top_level = true` i actualitzant la posició per `lerp` a cada frame.
- **Recompte de checkpoints:** El total de checkpoints es compta consultant el grup `checkpoints`, però els nodes s'afegeixen al grup dins del seu `_ready()`; el `RaceManager` espera un frame (`await get_tree().process_frame`) abans de comptar per evitar un total de 0.
- **Checkpoint repetit:** Creuar el mateix checkpoint diverses vegades incrementava el contador. Solucionat amb una bandera `_activated` a `checkpoint.gd` que fa que cada checkpoint només es registri un cop.
- **Pausa amb Escape obria i tancava al mateix frame:** La mateixa pulsació detectada pel `RaceManager` i pels botons del menú podia alternar l'estat dues vegades. Solucionat centralitzant la detecció al `pause_menu.gd` via `_unhandled_input` (és l'única acció `pause` de l'InputMap) i protegint `show_menu()`/`hide_menu()` perquè ignorin crids redundants.
- **Àudio sense fitxers:** En lloc de trencar-se quan manca un fitxer, l'`AudioManager` fa `ResourceLoader.exists()` i imprimeix un missatge a consola; el joc es manté jugable silenciosament.
- **Error de parseig al menú principal:** El fitxer `main_menu.tscn` contenia un `sub_resource` amb sintaxi invàlida (`Gradient(1, 1, 1, 1)`), fet que feia que la finestra es tanqués immediatament en arrencar (l'escena principal no carregava). Solucionat eliminant el recurs, que a més no era utilitzat per cap node.
- **Rutes de botons del menú:** Els botons "Tornar" dels panells de controls/crèdits es cercaven amb la ruta incorrecta (`BackButton` en lloc de `VBoxContainer/BackButton`), trencant el `_ready()` del menú. Solucionat corregint les rutes.
- **API de prioritat física:** `physics_process_priority` no existeix a Godot 4; la propietat correcta és `process_physics_priority`. Solucionat al `conveyor.gd`.
- **Verificació automàtica:** S'han afegit scripts de comprovació a `proyecto/tools/` (`check_scenes.gd`, `smoke_test.gd` i `flow_test.gd`) que permeten validar totes les escenes, executar uns frames de joc i recórrer el flux complet en mode headless des de consola.

### Testatge

- Proves manuals de moviment: el jugador es mou, salta i aterra correctament en totes les superfícies del curs.
- Proves de col·lisió: el pèndol aplica impulsos coherents amb la direcció de l'oscil·lació.
- Proves de checkpoints: el jugador reapareix correctament al checkpoint activat més recent en caure al pla de mort; el contador del HUD marca `x/3` correctament.
- Proves de cronòmetre: el temps s'atura en arribar a la meta i aplica la penalització (+2.5 s) en cada respawn.
- Proves de límits: el jugador no pot sortir del curs lateralment gràcies a les parets laterals del tram de cinta.
- **Proves de flux complet:** menú → carrera (amb fade) → pausa/reprendre/reiniciar → meta → rècord actualitzat al menú.
- **Proves de persistència:** el rècord es manté en reiniciar el joc (fitxer `user://best_time.save`).
- **Proves de pausa:** el joc s'atura de veritat (física i cronòmetre) amb `Escape` i es reprèn sense errors.
- **Verificació headless:** les 12 escenes del projecte carreguen correctament (`12/12 scenes OK`) i el test de fum executa menú i partida uns frames sense cap error de script (`SMOKE OK`).
- **Flux de joc complet automatitzat:** el test d'integració `tools/flow_test.gd` recorre el joc real sense intervenció humana i comprova 14 punts: que el botó INICIAR carrega la carrera, que hi ha 3 checkpoints comptats, que el cronòmetre avança, que el jugador es mou amb `W` i que salta amb `Espai`, que creuar un checkpoint incrementa el comptador i actualitza el HUD, que creuar la meta acaba la carrera i que caure al buit respawna amb la penalització de +2.5 s. Resultat: `RESULT: TODO OK`.

Aquestes proves es repeteixen des de l'arrel del repositori amb:

```bash
godot --headless --path proyecto -s res://tools/check_scenes.gd
godot --headless --path proyecto -s res://tools/smoke_test.gd
godot --headless --path proyecto -s res://tools/flow_test.gd
```

---

## 5. Ús d'Intel·ligència Artificial

Durant aquesta fase del projecte s'ha utilitzat IA (Freebuff, de Codebuff) per a les tasques següents:

- **Generació d'idees d'arquitectura:** Proposta de la separació entre `_control_velocity` i `_belt_velocity` per resoldre el conflicte física-cinta.
- **Documentació:** Generació i actualització d'aquest informe de seguiment a partir del codi font real del projecte.
- **Detecció de problemes:** Identificació de la necessitat d'afegir `process_physics_priority` al conveyor i de fer servir `top_level = true` per a la càmera.
- **Implementació de la Fita 3 i 4:** Amb assistència d'IA s'han generat el menú principal, el menú de pausa, l'`AudioManager`, el `TransitionManager`, la persistència del rècord, les animacions procedurals i les partícules, seguint les convencions ja existents al codi (senyals, grups, scripts modulars).
- **Generació d'assets d'àudio:** Implementació de `proyecto/tools/generate_audio.py`, un sintetitzador en Python que crea la música en bucle i els quatre SFX des de zero (ones quadrades/triangulars, envolvents i soroll).

Tot el codi ha estat revisat i comprès per l'autor. Les decisions tècniques finals han estat validades manualment.

---

## Checklist de l'Entrega

| Punt                                       | Estat |
| ------------------------------------------ | ----- |
| La mecànica principal funciona             | ✅    |
| Existeix una escena de joc operativa       | ✅    |
| Els controls estan definits i funcionen    | ✅    |
| El codi és modular i comprensible          | ✅    |
| Existeix estructura de carpetes correcta   | ✅    |
| **Pantalla inicial (menú principal)**      | ✅    |
| **Menú de pausa**                          | ✅    |
| **Millores de HUD (checkpoints + rècord)** | ✅    |
| **Persistència de dades (rècord)**         | ✅    |
| **Animacions del personatge**              | ✅    |
| **Transicions de pantalla (fade)**         | ✅    |
| **Feedback visual (partícules)**           | ✅    |
| **Àudio (música + SFX inclosos)**          | ✅    |
| **README.md complet**                      | ✅    |
| **.gitignore**                             | ✅    |
| **Build executable (temporal)**            | ✅    |
