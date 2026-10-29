# Personajes 3D

Los modelos vienen del **Ultimate Animated Character Pack** de Quaternius, con
licencia **CC0** y **todos son GLB animados** (con esqueleto y clips), así que
ninguno se queda tieso en la carrera. La lista, los nombres, la altura objetivo
y las rutas viven en `scripts/character_catalog.gd`; añadir otro modelo es una
entrada más en el catálogo, sin tocar la escena del menú (las filas del submenú
Personaje se generan desde la lista).

`CharacterCatalog.build_model` escala cada cuerpo a la misma altura y renombra
los clips a los que esperan el jugador y los bots.

## `ultimate/` — Quaternius, Ultimate Animated Character Pack (CC0)

- Autor: Quaternius — https://quaternius.com
- Pack: https://quaternius.com/packs/ultimatedanimatedcharacter.html
- Licencia: **CC0** (ver `ultimate/LICENSE_Quaternius.txt`).
- Diez personajes y **dos cuerpos por personaje** (masculino y femenino), veinte
  GLB en total:

  | Personaje | Cuerpos                   | Personaje | Cuerpos                     |
  | --------- | ------------------------- | --------- | --------------------------- |
  | Chef      | `chef_male` / `_female`   | Pirata    | `pirate_male` / `_female`   |
  | Obrero    | `worker_male` / `_female` | Vikingo   | `viking_male` / `_female`   |
  | Cowboy    | `cowboy_male` / `_female` | Kimono    | `kimono_male` / `_female`   |
  | Ninja     | `ninja_male` / `_female`  | Soldado   | `soldier_male` / `_female`  |
  | Ejecutivo | `suit_male` / `_female`   | Caballero | `knight_golden_*`           |

- **Los dos cuerpos cuentan como un solo personaje**: se desbloquean juntos,
  ocupan una fila del menú y el jugador corre con uno de ellos (se sortea al
  arrancar y se mantiene durante toda la sesión); los bots se reparten entre los
  dos, así que en la parrilla se ven las dos versiones.
- Clips originales del pack (`CharacterArmature|…`): `Idle`, `Walk`, `Walk_Carry`,
  `Punch`, `RecieveHit`, `Victory`, `Defeat`, `PickUp`, `SitDown`, `StandUp` y
  `Shoot_OneHanded`. El catálogo los mapea a los alias que usa el juego; **el
  pack no trae clip de carrera ni de salto**, así que `Running_A` reutiliza el
  andar acelerado (×2,4), en el aire se congela una zancada de esa carrera y el
  rig procedural (`scripts/character_rig.gd`) inclina el torso al esprintar,
  recoge piernas y brazos en el salto y flexiona el aterrizaje.
- **Acabado de juguete**: `build_model` sustituye el material plano de cada
  superficie por `shaders/character.gdshader` (toon + brillo plástico + borde),
  así que los cuerpos casan con los circuitos.
- Los `.glb` salen de convertir los FBX del pack con FBX2glTF 0.9.7: misma
  geometría, materiales y animaciones, en un contenedor que Godot importa sin
  plugins.

## Añadir un personaje

1. Copia los `.glb` (uno por cuerpo) a `ultimate/` y su licencia al lado.
2. Comprueba que traen los ocho clips que piden jugador y bots
   (`godot --headless -s res://tools/probe_catalog.gd`); el catálogo renombra
   los que vengan con otro nombre desde `CLIP_ALIASES`, pero un modelo sin
   esqueleto no sirve: se quedaría quieto.
3. Añade la entrada en `CharacterCatalog.CHARACTERS` (`id`, `name`, `variants`,
   `color`, `price`).
4. Nada más: el submenú Personaje crea la fila a partir del catálogo.
