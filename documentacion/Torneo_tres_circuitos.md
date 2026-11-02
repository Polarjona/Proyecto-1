# Torneo de tres circuitos

**Proyecto:** Tumble Rush
**Autores:** Pol Arjona e Yazan Issa
**Motor:** Godot Engine 4.7.2 (Forward Plus, Jolt)
**Fecha:** Octubre 2026

---

## 1. Objetivo

El modo torneo tenía una sola carrera larga (`main.tscn`). Ahora tiene **tres
rondas con tres circuitos distintos**, unidos por `GameSession`:

| Ronda | Escena | Nombre | Longitud | Checkpoints |
| --- | --- | --- | --- | --- |
| 1 | `scenes/main.tscn` | Pivot Push | ~368 m | 11 |
| 2 | `scenes/levels/spin_go_round.tscn` | Spin Go Round | ~339 m | 12 |
| 3 | `scenes/levels/pivot_panic.tscn` | Pivot Panic | ~323 m | 11 |

Cada nivel lleva un `LevelInfo` con id, ronda, tiempos de medalla, récord
propio y la ruta de los bots. `RaceManager` y `RaceDirector` leen esos datos,
así que el mismo jugador y el mismo bot funcionan en las tres rondas.

## 2. Referencias y paletas

La composición y el color se inspiraron en dos mapas de Stumble Guys de
Sketchfab (CC-BY 4.0, autor **amogusstrikesback2**):

- [Pivot Push](https://sketchfab.com/3d-models/stumble-guys-pivot-push-map-c7abc0bdd0a8490d9f1e9c805e3c05cd)
- [Spin Go Round](https://sketchfab.com/3d-models/stumble-guys-spin-go-round-map-71224cc13db44948b91b8bb43c635d5c)

No se descargaron sus mallas: la API de descarga de Sketchfab exige una cuenta
autenticada. Se usaron sus vistas previas para estudiar layout, familias de
color y siluetas, y se construyeron circuitos originales con CSG, mallas y
materiales del proyecto. Las dos vistas previas quedan en
`documentacion/referencias/` con la misma atribución CC-BY 4.0.

| Circuito | Base | Acentos | Cielo / mar |
| --- | --- | --- | --- |
| Pivot Push | azul real, magenta y rosa claro | oro, crema | azul profundo con islas pastel |
| Spin Go Round | cian y azul | naranja, magenta, lima, oro | turquesa luminoso con mar de nubes |
| Pivot Panic | magenta intenso y rosa | azul real, oro, crema | crema rosado y mar magenta |

Materiales nuevos: `pivot_floor`, `pivot_floor_alt`, `pivot_blue`,
`pivot_gold`, `pivot_wall`, `pivot_rail`, `pivot_cream`, `spin_floor`,
`spin_blue`, `spin_orange`, `spin_magenta`, `spin_lime`, `spin_gold`,
`spin_wall` y `spin_hazard` (rayas de peligro con shader propio).

## 3. Pivot Push (ronda 1)

Es el circuito original, retematizado de azul/cian/lima a **azul real,
magenta y oro**. Se conservan los tramos y se añadió un **balancín** en el
hueco entre las cintas y la avenida de martillos, con su base, rampa y landing.
La cámara, los 11 checkpoints y los 7 bots siguen usando la misma ruta de
siempre; `LevelInfo` ahora la expone también en el inspector.

**Acto 3 — la forja** (todo nuevo): tras la plaza de la antigua meta, una
rampa baja al **pasillo de las rocas** (dos rocas persecutorias por los
carriles de fuera, con el centro libre y **cinta en contra**), sube a la
**terraza de pinchos** (8 trampas) y cruza el **puente de las aspas** de 20 m
con tres brazos giratorios. Después, **subida larga de 18 m** hasta la cima,
con barrido y **dos péndulos** encima, y una **bajada de 18 m** hasta la recta
final: dos barridos, cinta en contra y cuatro pinchos antes de la meta.

## 4. Spin Go Round (ronda 2)

El circuito más largo del torneo: **339 m y 12 checkpoints**, en tres actos que
alternan altura, persecuciones y obstáculos de suelo.

**Acto 1 — arena y peonzas**

- salida con arco y **dos barridos** en una arena con pasillos cerrados;
- pasarela estrecha y **plataforma móvil** sobre el vacío;
- **tramo de peonzas**: barrido, disco giratorio y lluvia de bolas.

**Acto 2 — altura**

- **rampa de subida** a una plataforma alta con **dos pistones** alternos
  (bloque sólido que sale de la pared con luz de aviso);
- **puente de 12 losas frágiles** que tiemblan, se desploman y vuelven a
  aparecer, para que el pelotón pueda seguir cruzando;
- **rampa de bajada**, recta final y **subida final** a la plaza intermedia.

**Acto 3 — el descenso y el mirador** (todo nuevo)

- **pasillo de las rocas**: tres **rocas persecutorias** ruedan en contra de la
  marcha por tres carriles desfasados y hay que dejarles hueco de lado;
- **galería de pinchos**: 16 **trampas de pinchos** en 4 × 4 con aviso en rojo
  antes de que salgan del suelo y golpeen hacia arriba;
- **puente de las aspas**: pasarela de 4,6 m con tres **aspas giratorias** que
  barren a la altura de las piernas y hay que saltar;
- **cinta en contra** en el aterrizaje, para que el último metro cueste;
- **subida larga al mirador** (24 m, +5,4 m) con lluvia de bolas en la cuesta;
- **mirador**: barrido y **dos péndulos** en la plataforma más alta del mapa;
- **bajada final** de 24 m con bolas rodando cuesta abajo y dos barridos de
  cierre sobre la recta final.

Los bots esperan la plataforma móvil, pasan los pistones, esquivan las rocas,
saltan las aspas y cruzan los pinchos; el tramo se validó con
`tools/levels_bots_test.gd` (entre 80 y 100 s, 0 o 1 rescates).

## 5. Pivot Panic (ronda 3)

La final mezcla los obstáculos que mejor encajan con Pivot Push:

1. barrido de entrada y balancín central con **gran bastidor dorado**;
2. rampa de salida y **avenida de cuatro péndulos** con marcos dorados;
3. plataforma móvil y **puente del viento** con dos túneles opuestos;
4. **cañón** que cruza el vacío hasta la plataforma del cañón;
5. recta final con barrido, péndulo y **trampolín** que sube a la meta 4 m.

Tiene 5 checkpoints en la primera mitad para que una caída no obligue a repetir
el circuito entero. El bot de prueba termina en ~39 s con un par de rescates; el
jugador tiene margen para repetir el tramo del cañón o el péndulo.

**Acto 3 — la garganta** (todo nuevo, 11 checkpoints en total): rampa de
bajada, **pasillo de las rocas** (tres rocas en contra), **terraza de 12
trampas de pinchos**, **puente del vendaval** con viento cruzado y **tres aspas
giratorias**, cinta en contra y aterrizaje; luego **subida de 18 m a la
cumbre** con barrido y dos péndulos, **bajada de 20 m** y recta final con dos
barridos, cinta en contra y cuatro pinchos.

## 6. Récords y medallas

Cada circuito guarda su propio récord y sus splits en
`user://profile.json` (`best_times` y `best_splits_by_level`). Los tiempos de
medalla son:

| Circuito | Oro | Plata | Bronce |
| --- | --- | --- | --- |
| Pivot Push | 130 s | 170 s | 215 s |
| Spin Go Round | 115 s | 145 s | 185 s |
| Pivot Panic | 120 s | 155 s | 195 s |

El HUD muestra la medalla de oro del circuito cargado y el panel de resultados
indica la ronda y el puesto. Al clasificarse, «Siguiente ronda» avanza a la
escena correspondiente; en la final el torneo se cierra.

## 7. Cómo se generan las escenas

Las dos escenas nuevas se generan con:

```bash
cd proyecto
godot --headless --path . res://tools/build_levels.tscn
```

`tools/build_levels.gd` comparte el entorno (cielo, luces, postproceso, HUD,
RaceManager, KillPlane, RaceDirector, jugador y pausa), construye cada
plataforma y obstáculo, asigna `LevelInfo` y empaqueta el resultado en
`scenes/levels/`. Así los tres mapas usan exactamente el mismo contrato de
carrera y se pueden regenerar tras ajustar la paleta o la ruta.

## 8. Verificación

- `tools/check_scenes.gd`: **26/26 escenas OK**.
- `tools/levels_test.gd`: tres circuitos cargan, `LevelInfo`, checkpoints,
  metas, rutas de bots y decoración; flujo de tres rondas del torneo.
- `tools/levels_bots_test.gd`: un bot completa Spin Go Round y Pivot Panic.
- `smoke_test`, `flow_test`, `features_test`, `iteration3_test`,
  `iteration4_test` e `iteration5_test`: **TODO OK**.
- `bots_test`: los 7 bots terminan el circuito original; conserva el aviso
  conocido del primer waypoint y el presupuesto de rescates (máx. 4 en la
  última ejecución) porque el test es más estricto que el juego.

## 9. Atrezo descargado

`assets/props/beach_ball.glb` es una **pelota de playa CC-BY 3.0** de
**the_ normalgamer**, descargada de
[Poly Pizza](https://poly.pizza/m/4IwPTeOmq6c). Se usa como decoración en
Spin Go Round y Pivot Panic; la atribución completa está en
`assets/props/README.md`.

## 10. Limitaciones

- Las plataformas siguen siendo `CSGBox3D` en runtime. El siguiente paso es
  hornear mallas y colisión trimesh para reducir draw calls.
- La descarga directa de los modelos de Sketchfab requiere autenticación; por
  eso se usaron como referencia y se incorporó un modelo CC-BY equivalente.
- La geometría de los tres mapas está pensada para el control actual (sin
  cámara libre); si se añade multijugador habrá que revisar los carriles.
