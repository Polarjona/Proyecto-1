class_name Localization

extends RefCounted

## Traducciones de la interfaz. Las claves son el texto en español que ya usan
## escenas y scripts; así los controles se traducen solos al cambiar el idioma
## y los textos dinámicos solo necesitan envolver la plantilla en `tr()`.
##
## No se usan recursos importados: las traducciones se construyen al arrancar.
## Eso mantiene los tests headless y la exportación sin pasos de importación.

const SUPPORTED := ["es", "ca", "en"]

const CATALAN := {
	# --- Menú principal -----------------------------------------------------
	"PERSONAJE": "PERSONATGE",
	"AJUSTES": "AJUSTOS",
	"CONTROLES": "CONTROLS",
	"CRÉDITOS": "CRÈDITS",
	"SALIR": "SORTIR",
	"JUGAR!": "JUGAR!",
	"ELIGE MODO": "TRIA MODE",
	"VOLVER": "TORNA",
	"CARRERA CLÁSICA": "CURSA CLÀSSICA",
	"Los cinco circuitos, contra el cronómetro. Persigue tu récord y las medallas.":
	"Els cinc circuits, contra el cronòmetre. Persegueix el teu rècord i les medalles.",
	"SOLO": "SOL",
	"CIRCUITO DE LA CARRERA CLÁSICA": "CIRCUIT DE LA CURSA CLÀSSICA",
	"MODO TORNEO": "MODE TORNEIG",
	"4 rondas, 4 circuitos. Clasifícate en el top 3 y llega a la final.":
	"4 rondes, 4 circuits. Classifica't entre els 3 primers i arriba a la final.",
	"4 RONDAS": "4 RONDES",
	"El torneo recorre cuatro circuitos en orden; el quinto es solo para la carrera clásica.":
	"El torneig recorre quatre circuits en ordre; el cinquè és només per a la cursa clàssica.",
	"PROGRESO AL ORO": "PROGRÉS CAP A L'OR",
	"Sin récord todavía": "Sense rècord encara",
	"Medalla de oro: 70.0 s": "Medalla d'or: 70.0 s",
	"Corre, gana monedas y desbloquea los 10 corredores.":
	"Corre, guanya monedes i desbloqueja els 10 corredors.",
	"Desbloqueada": "Desbloquejada",
	"Objetivo: %s. Oro ≤ %s s · bronce ≤ %s s.": "Objectiu: %s. Or ≤ %s s · bronze ≤ %s s.",
	"Récord %s: %s s": "Rècord %s: %s s",
	"Mejor medalla: %s": "Millor medalla: %s",
	"Sin récord en %s": "Sense rècord a %s",
	"Oro ≤ %s s · bronce ≤ %s s": "Or ≤ %s s · bronze ≤ %s s",
	"Corre una carrera y persigue la medalla": "Corre una cursa i persegueix la medalla",
	"%d monedas": "%d monedes",
	"Bloqueada · %d monedas": "Bloquejada · %d monedes",
	"DESBLOQUEAR POR %d MONEDAS": "DESBLOQUEJA PER %d MONEDES",
	"Bloqueada · te faltan %d monedas": "Bloquejada · et falten %d monedes",
	"NECESITAS %d MONEDAS": "NECESSITES %d MONEDES",
	"ELEGIR PERSONAJE": "ESCULL PERSONATGE",
	"Desbloqueada · lista para correr": "Desbloquejada · a punt per córrer",
	"ELEGIDO": "ESCULLIT",
	"LIBRE": "LLIURE",
	"Chef": "Chef",
	"Obrero": "Obrer",
	"Cowboy": "Cowboy",
	"Ninja": "Ninja",
	"Pirata": "Pirata",
	"Vikingo": "Viking",
	"Kimono": "Kimono",
	"Soldado": "Soldat",
	"Ejecutivo": "Executiu",
	"Caballero": "Cavaller",
	"Moverte:  W A S D  o  flechas": "Moure't:  W A S D  o  fletxes",
	"Cámara:  Ratón  o  stick derecho": "Càmera:  Ratolí  o  stick dret",
	"Reiniciar carrera:  R": "Reinicia la cursa:  R",
	"Saltar:  Espacio  (mantén para saltar más alto)":
	"Saltar:  Espai  (mantén per saltar més alt)",
	"Pausa:  Escape  o  Start del mando": "Pausa:  Escape  o  Start del comandament",
	"Objetivo: cruza el circuito y persigue la medalla de oro.":
	"Objectiu: creua el circuit i persegueix la medalla d'or.",
	"Autores: Pol Arjona y Yazan Issa": "Autors: Pol Arjona i Yazan Issa",
	"Motor: Godot Engine 4.7": "Motor: Godot Engine 4.7",
	"Desarrollo asistido por IA (Freebuff)": "Desenvolupament assistit per IA (Freebuff)",
	# --- Pausa --------------------------------------------------------------
	"PAUSA": "PAUSA",
	"CONTINUAR": "CONTINUA",
	"REINICIAR CHECKPOINT": "REINICIA EL PUNT DE CONTROL",
	"REINICIAR CARRERA": "REINICIA LA CURSA",
	"MENÚ PRINCIPAL": "MENÚ PRINCIPAL",
	# --- Ajustes ------------------------------------------------------------
	"Música": "Música",
	"Efectos": "Efectes",
	"Sacudida": "Sacsejada",
	"Sensibilidad": "Sensibilitat",
	"PANTALLA COMPLETA: NO": "PANTALLA COMPLETA: NO",
	"PANTALLA COMPLETA: SÍ": "PANTALLA COMPLETA: SÍ",
	"General": "General",
	"Calidad": "Qualitat",
	"BORRAR PROGRESO": "ESBORRA EL PROGRÉS",
	"Borrar progreso": "Esborrar el progrés",
	(
		"Se borran récord, monedas, medallas, desbloqueos y el tutorial.\n"
		+ "Los ajustes de audio y pantalla se conservan."
	):
	(
		"S'esborren rècord, monedes, medalles, desbloquejos i el tutorial.\n"
		+ "Els ajustos d'àudio i pantalla es conserven."
	),
	"REDUCIR MOVIMIENTO": "REDUEIX EL MOVIMENT",
	"Reiniciar carrera": "Reinicia la cursa",
	"Se perderá el progreso de esta carrera.": "Es perdrà el progrés d'aquesta cursa.",
	"Volver al menú": "Torna al menú",
	"Se perderá la carrera actual.": "Es perdrà la cursa actual.",
	"BAJO": "BAIX",
	"MEDIO": "MITJÀ",
	"ALTO": "ALT",
	"NO": "NO",
	"SÍ": "SÍ",
	"%d%%": "%d%%",
	"FOV": "FOV",
	"V-SYNC: NO": "V-SYNC: NO",
	"V-SYNC: SÍ": "V-SYNC: SÍ",
	"ASISTIDO: NO": "ASISTIT: NO",
	"ASISTIDO: SÍ": "ASISTIT: SÍ",
	"IDIOMA: ES": "IDIOMA: ES",
	"IDIOMA: CA": "IDIOMA: CA",
	"IDIOMA: EN": "IDIOMA: EN",
	# --- HUD ----------------------------------------------------------------
	"Récord: --": "Rècord: --",
	"Oro ≤ --": "Or ≤ --",
	"¡META!": "¡META!",
	"Tiempo: 0.00 s": "Temps: 0.00 s",
	"Medalla: SIN MEDALLA": "Medalla: SENSE MEDALLA",
	"REINTENTAR": "TORNA A INTENTAR-HO",
	"SIGUIENTE RONDA": "SEGÜENT RONDA",
	"MENÚ": "MENÚ",
	"¡A CORRER!": "A CORRER!",
	"¡YA!": "JA!",
	"ENTENDIDO": "ENTESOS",
	(
		"Moverte: WASD / flechas · Saltar: Espacio\n"
		+ "Esc: pausa · trampolines y cañones te lanzan solos\n"
		+ "Cruza el circuito y persigue la medalla de oro"
	):
	(
		"Moure't: WASD / fletxes · Saltar: Espai\n"
		+ "Esc: pausa · trampolins i canons et llancen sols\n"
		+ "Creua el circuit i persegueix la medalla d'or"
	),
	"Oro ≤ %s": "Or ≤ %s",
	"Récord: %s": "Rècord: %s",
	"Tiempo: %s": "Temps: %s",
	"Récord: %s  ·  ¡NUEVO!": "Rècord: %s  ·  NOU!",
	"Medalla: %s": "Medalla: %s",
	"+%s s  (caída)": "+%s s  (caiguda)",
	"%s  %s s%s": "%s  %s s%s",
	"+%d monedas (total %d) · %s": "+%d monedes (total %d) · %s",
	"sin caídas": "sense caigudes",
	"1 caída": "1 caiguda",
	"%d caídas": "%d caigudes",
	"Ronda %d/%d · %d.º/%d": "Ronda %d/%d · %d.è/%d",
	"%d.º/%d": "%d.è/%d",
	"Ronda %d/%d · %d.º/%d · %s": "Ronda %d/%d · %d.è/%d · %s",
	"%d.º/%d · %s": "%d.è/%d · %s",
	"Puesto %d de %d · clasifican %d": "Posició %d de %d · es classifiquen %d",
	"Ronda %d/%d · Puesto %d de %d · %s": "Ronda %d/%d · Posició %d de %d · %s",
	"Ronda %d/%d · %s": "Ronda %d/%d · %s",
	"Base %d": "Base %d",
	"Tiempo %d": "Temps %d",
	"Puesto %dº %d": "Posició %dè %d",
	"Medalla %d": "Medalla %d",
	"Pulsa REINTENTAR para volver a la salida.":
	"Prem TORNA A INTENTAR-HO per tornar a la sortida.",
	"La lava te alcanzó": "La lava t'ha atrapat",
	"Caíste al vacío": "Has caigut al buit",
	"VOLVER AL LOBBY": "TORNA AL LOBBY",
	"¡CAMPEÓN!": "¡CAMPIO!",
	"¡ELIMINADO!": "¡ELIMINAT!",
	"CLASIFICADO": "CLASSIFICAT",
	"ELIMINADO": "ELIMINAT",
	"CAMPEÓN DEL TORNEO": "CAMPIO DEL TORNEIG",
	"¡HAS PERDIDO!": "¡HAS PERDUT!",
	"ORO": "OR",
	"PLATA": "PLATA",
	"BRONCE": "BRONZE",
	"SIN MEDALLA": "SENSE MEDALLA",
	# --- Tutorial guiado ----------------------------------------------------
	"CORRE": "CORRE",
	"SALTA": "SALTA",
	"SIGUE": "SEGUEIX",
	"Corre hacia la flecha": "Corre cap a la fletxa",
	"Salta para superar el obstáculo": "Salta per superar l'obstacle",
	"Sigue el circuito hasta la meta": "Segueix el circuit fins a la meta",
	# --- Circuitos y personajes --------------------------------------------
	"Checkpoint 1": "Punt de control 1",
	"Checkpoint 2": "Punt de control 2",
	"Checkpoint 3": "Punt de control 3",
	"Checkpoint 4": "Punt de control 4",
	"Checkpoint 5": "Punt de control 5",
	"Checkpoint 6": "Punt de control 6",
	"Checkpoint 7": "Punt de control 7",
	"Checkpoint 8": "Punt de control 8",
	"Checkpoint 9": "Punt de control 9",
	"Checkpoint 10": "Punt de control 10",
	"Checkpoint 11": "Punt de control 11",
	"Checkpoint 12": "Punt de control 12",
}

const ENGLISH := {
	# --- Main menu ----------------------------------------------------------
	"PERSONAJE": "CHARACTER",
	"AJUSTES": "SETTINGS",
	"CONTROLES": "CONTROLS",
	"CRÉDITOS": "CREDITS",
	"SALIR": "QUIT",
	"JUGAR!": "PLAY!",
	"ELIGE MODO": "CHOOSE MODE",
	"VOLVER": "BACK",
	"CARRERA CLÁSICA": "CLASSIC RACE",
	"Los cinco circuitos, contra el cronómetro. Persigue tu récord y las medallas.":
	"All five courses against the clock. Chase your record and the medals.",
	"SOLO": "SOLO",
	"CIRCUITO DE LA CARRERA CLÁSICA": "CLASSIC RACE COURSE",
	"MODO TORNEO": "TOURNAMENT MODE",
	"4 rondas, 4 circuitos. Clasifícate en el top 3 y llega a la final.":
	"4 rounds, 4 courses. Finish in the top 3 and reach the final.",
	"4 RONDAS": "4 ROUNDS",
	"El torneo recorre cuatro circuitos en orden; el quinto es solo para la carrera clásica.":
	"The tournament runs four courses in order; the fifth is only for classic race.",
	"PROGRESO AL ORO": "PROGRESS TO GOLD",
	"Sin récord todavía": "No record yet",
	"Medalla de oro: 70.0 s": "Gold medal: 70.0 s",
	"Corre, gana monedas y desbloquea los 10 corredores.":
	"Run, earn coins and unlock all 10 runners.",
	"Desbloqueada": "Unlocked",
	"Objetivo: %s. Oro ≤ %s s · bronce ≤ %s s.": "Goal: %s. Gold ≤ %s s · bronze ≤ %s s.",
	"Récord %s: %s s": "Record %s: %s s",
	"Mejor medalla: %s": "Best medal: %s",
	"Sin récord en %s": "No record on %s",
	"Oro ≤ %s s · bronce ≤ %s s": "Gold ≤ %s s · bronze ≤ %s s",
	"Corre una carrera y persigue la medalla": "Run a race and chase the medal",
	"%d monedas": "%d coins",
	"Bloqueada · %d monedas": "Locked · %d coins",
	"DESBLOQUEAR POR %d MONEDAS": "UNLOCK FOR %d COINS",
	"Bloqueada · te faltan %d monedas": "Locked · %d coins short",
	"NECESITAS %d MONEDAS": "YOU NEED %d COINS",
	"ELEGIR PERSONAJE": "CHOOSE CHARACTER",
	"Desbloqueada · lista para correr": "Unlocked · ready to run",
	"ELEGIDO": "SELECTED",
	"LIBRE": "FREE",
	"Chef": "Chef",
	"Obrero": "Worker",
	"Cowboy": "Cowboy",
	"Ninja": "Ninja",
	"Pirata": "Pirate",
	"Vikingo": "Viking",
	"Kimono": "Kimono",
	"Soldado": "Soldier",
	"Ejecutivo": "Executive",
	"Caballero": "Knight",
	"Moverte:  W A S D  o  flechas": "Move:  W A S D  or  arrows",
	"Cámara:  Ratón  o  stick derecho": "Camera:  Mouse  or  right stick",
	"Reiniciar carrera:  R": "Restart race:  R",
	"Saltar:  Espacio  (mantén para saltar más alto)": "Jump:  Space  (hold to jump higher)",
	"Pausa:  Escape  o  Start del mando": "Pause:  Escape  or  controller Start",
	"Objetivo: cruza el circuito y persigue la medalla de oro.":
	"Goal: complete the course and chase the gold medal.",
	"Autores: Pol Arjona y Yazan Issa": "Authors: Pol Arjona and Yazan Issa",
	"Motor: Godot Engine 4.7": "Engine: Godot Engine 4.7",
	"Desarrollo asistido por IA (Freebuff)": "AI-assisted development (Freebuff)",
	# --- Pause --------------------------------------------------------------
	"PAUSA": "PAUSE",
	"CONTINUAR": "CONTINUE",
	"REINICIAR CHECKPOINT": "RESTART CHECKPOINT",
	"REINICIAR CARRERA": "RESTART RACE",
	"MENÚ PRINCIPAL": "MAIN MENU",
	# --- Settings -----------------------------------------------------------
	"Música": "Music",
	"Efectos": "Effects",
	"Sacudida": "Shake",
	"Sensibilidad": "Sensitivity",
	"PANTALLA COMPLETA: NO": "FULLSCREEN: NO",
	"PANTALLA COMPLETA: SÍ": "FULLSCREEN: YES",
	"General": "General",
	"Calidad": "Quality",
	"BORRAR PROGRESO": "DELETE PROGRESS",
	"Borrar progreso": "Delete progress",
	(
		"Se borran récord, monedas, medallas, desbloqueos y el tutorial.\n"
		+ "Los ajustes de audio y pantalla se conservan."
	):
	(
		"This deletes records, coins, medals, unlocks and the tutorial.\n"
		+ "Audio and display settings are kept."
	),
	"REDUCIR MOVIMIENTO": "REDUCE MOTION",
	"Reiniciar carrera": "Restart race",
	"Se perderá el progreso de esta carrera.": "Progress from this race will be lost.",
	"Volver al menú": "Back to menu",
	"Se perderá la carrera actual.": "The current race will be lost.",
	"BAJO": "LOW",
	"MEDIO": "MEDIUM",
	"ALTO": "HIGH",
	"NO": "NO",
	"SÍ": "YES",
	"%d%%": "%d%%",
	"FOV": "FOV",
	"V-SYNC: NO": "V-SYNC: NO",
	"V-SYNC: SÍ": "V-SYNC: YES",
	"ASISTIDO: NO": "ASSISTED: NO",
	"ASISTIDO: SÍ": "ASSISTED: YES",
	"IDIOMA: ES": "LANGUAGE: ES",
	"IDIOMA: CA": "LANGUAGE: CA",
	"IDIOMA: EN": "LANGUAGE: EN",
	# --- HUD ----------------------------------------------------------------
	"Récord: --": "Record: --",
	"Oro ≤ --": "Gold ≤ --",
	"¡META!": "FINISH!",
	"Tiempo: 0.00 s": "Time: 0.00 s",
	"Medalla: SIN MEDALLA": "Medal: NO MEDAL",
	"REINTENTAR": "RETRY",
	"SIGUIENTE RONDA": "NEXT ROUND",
	"MENÚ": "MENU",
	"¡A CORRER!": "LET'S RUN!",
	"¡YA!": "GO!",
	"ENTENDIDO": "GOT IT!",
	(
		"Moverte: WASD / flechas · Saltar: Espacio\n"
		+ "Esc: pausa · trampolines y cañones te lanzan solos\n"
		+ "Cruza el circuito y persigue la medalla de oro"
	):
	(
		"Move: WASD / arrows · Jump: Space\n"
		+ "Esc: pause · trampolines and cannons launch you\n"
		+ "Complete the course and chase the gold medal"
	),
	"Oro ≤ %s": "Gold ≤ %s",
	"Récord: %s": "Record: %s",
	"Tiempo: %s": "Time: %s",
	"Récord: %s  ·  ¡NUEVO!": "Record: %s  ·  NEW!",
	"Medalla: %s": "Medal: %s",
	"+%s s  (caída)": "+%s s  (fall)",
	"%s  %s s%s": "%s  %s s%s",
	"+%d monedas (total %d) · %s": "+%d coins (total %d) · %s",
	"sin caídas": "no falls",
	"1 caída": "1 fall",
	"%d caídas": "%d falls",
	"Ronda %d/%d · %d.º/%d": "Round %d/%d · %d/%d",
	"%d.º/%d": "%d/%d",
	"Ronda %d/%d · %d.º/%d · %s": "Round %d/%d · %d/%d · %s",
	"%d.º/%d · %s": "%d/%d · %s",
	"Puesto %d de %d · clasifican %d": "Place %d of %d · %d qualify",
	"Ronda %d/%d · Puesto %d de %d · %s": "Round %d/%d · Place %d of %d · %s",
	"Ronda %d/%d · %s": "Round %d/%d · %s",
	"Base %d": "Base %d",
	"Tiempo %d": "Time %d",
	"Puesto %dº %d": "Place %d · %d",
	"Medalla %d": "Medal %d",
	"Pulsa REINTENTAR para volver a la salida.": "Press RETRY to return to the start.",
	"La lava te alcanzó": "The lava caught you",
	"Caíste al vacío": "You fell into the void",
	"VOLVER AL LOBBY": "BACK TO LOBBY",
	"¡CAMPEÓN!": "CHAMPION!",
	"¡ELIMINADO!": "ELIMINATED!",
	"CLASIFICADO": "QUALIFIED",
	"ELIMINADO": "ELIMINATED",
	"CAMPEÓN DEL TORNEO": "TOURNAMENT CHAMPION",
	"¡HAS PERDIDO!": "YOU LOST!",
	"ORO": "GOLD",
	"PLATA": "SILVER",
	"BRONCE": "BRONZE",
	"SIN MEDALLA": "NO MEDAL",
	# --- Guided tutorial ----------------------------------------------------
	"CORRE": "RUN",
	"SALTA": "JUMP",
	"SIGUE": "FOLLOW",
	"Corre hacia la flecha": "Run towards the arrow",
	"Salta para superar el obstáculo": "Jump over the obstacle",
	"Sigue el circuito hasta la meta": "Follow the course to the finish",
	# --- Courses and characters --------------------------------------------
	"Checkpoint 1": "Checkpoint 1",
	"Checkpoint 2": "Checkpoint 2",
	"Checkpoint 3": "Checkpoint 3",
	"Checkpoint 4": "Checkpoint 4",
	"Checkpoint 5": "Checkpoint 5",
	"Checkpoint 6": "Checkpoint 6",
	"Checkpoint 7": "Checkpoint 7",
	"Checkpoint 8": "Checkpoint 8",
	"Checkpoint 9": "Checkpoint 9",
	"Checkpoint 10": "Checkpoint 10",
	"Checkpoint 11": "Checkpoint 11",
	"Checkpoint 12": "Checkpoint 12",
}

static var _installed: bool = false


static func apply(language: String) -> void:
	_install()
	var code := language if SUPPORTED.has(language) else "es"
	TranslationServer.set_locale(code)


static func _install() -> void:
	if _installed:
		return
	_installed = true
	# El español también necesita una traducción identidad: si una clave no
	# existe en su locale, Godot cae al inglés de respaldo y la interfaz
	# española se quedaría media en inglés.
	var spanish := {}
	for key: String in CATALAN:
		spanish[key] = key
	for key: String in ENGLISH:
		spanish[key] = key
	_add("es", spanish)
	_add("ca", CATALAN)
	_add("en", ENGLISH)


static func _add(locale: String, messages: Dictionary) -> void:
	var translation := Translation.new()
	translation.locale = locale
	for key: String in messages:
		translation.add_message(key, String(messages[key]))
	TranslationServer.add_translation(translation)
