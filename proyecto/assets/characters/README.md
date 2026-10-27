# Personajes 3D

Los modelos vienen de dos packs con licencia libre y **todos son GLB animados**
(con esqueleto y clips), así que ninguno se queda tieso en la carrera. La lista,
los nombres, la altura objetivo y las rutas viven en
`scripts/character_catalog.gd`; añadir otro modelo es una entrada más en el
catálogo y una fila más en el roster del menú.

`CharacterCatalog.build_model` escala cada cuerpo a la misma altura y renombra
los clips a los que esperan el jugador y los bots, así que los dos packs
conviven en la carrera.

## `mini/` — Kenney Mini Characters (CC0)

- Autor: Kenney — https://kenney.nl
- Pack: https://kenney.nl/assets/mini-characters
- Licencia: **CC0** (ver `mini/LICENSE_Kenney.txt`).
- Usados: `character-male-f.glb` (**Coco**), `character-female-d.glb`
  (**Menta**) y `character-female-b.glb` (**Nube**).
- Chibis de proporciones cortas con clips de idle, caminar, correr, salto,
  aterrizaje y caída.

## `mascots/` — Quaternius (CC0)

- Autor: Quaternius — https://quaternius.com, descargados de
  [poly.pizza](https://poly.pizza).
- Licencia: **CC0** (ver `mascots/LICENSE_Quaternius.txt`).
- Usados: `bunny.glb` (**Mochi**) y `robot.glb` (**Turbo**).
- Cuerpos redondeados de cabeza enorme, los más cercanos al tono *Fall Guys*.

## Añadir un personaje

1. Copia el `.glb` a la carpeta que corresponda y su licencia al lado.
2. Comprueba que trae los ocho clips que piden jugador y bots
   (`godot --headless -s res://tools/probe_catalog.gd`); el catálogo renombra
   los que vengan con otro nombre desde `CLIP_ALIASES`, pero un modelo sin
   esqueleto no sirve: se quedaría quieto.
3. Añade la entrada en `CharacterCatalog.CHARACTERS` (`id`, `name`, `scene`,
   `target_height`, `color`, `price`).
4. Añade su fila en `scenes/menu/main_menu.tscn` (patrón `CocoRow`) y su botón
   en los arrays `character_buttons` y `character_status` de `main_menu.gd`.
