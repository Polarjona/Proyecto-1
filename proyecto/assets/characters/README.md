# Personajes 3D

Modelos descargados del pack **Kenney Blocky Characters 2.0**.

- Licencia: **CC0** (ver `blocky/LICENSE_Kenney.txt`).
- Autor: Kenney — https://kenney.nl
- Pack original: https://kenney.nl/assets/blocky-characters

Archivos usados (en `blocky/`):

- `character-a.glb`: **Chispa**.
- `character-c.glb`: **Uva**.
- `character-e.glb`: **Robot**.
- `character-g.glb`: **Tornillo**.
- `character-m.glb`: **Jefe**.

Los cinco comparten esqueleto y animaciones de nodo, así que el jugador y los
bots usan el mismo código. La lista, los nombres, la altura objetivo y las
rutas viven en `scripts/character_catalog.gd`; añadir otro modelo del pack es
una entrada más. `CharacterCatalog.build_model` escala cada cuerpo a la misma
altura para que ninguno tenga ventaja en la carrera.
