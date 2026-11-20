#!/usr/bin/env python3
"""Comprueba que la documentación y sus datos no se separen del código.

Se ejecuta desde `proyecto/` como un test más de `tools/run_tests.sh`. No usa
dependencias externas: lee Markdown, escenas y scripts, y falla con una lista
de problemas si una cifra, un enlace, una imagen o un ancla dejan de coincidir.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "proyecto"
DOCS = ROOT / "documentacion"
SOURCE = DOCS / "Datos_circuitos.md"
CAPTURES_DOC = DOCS / "Capturas.md"
FOUR_DOCS = [
    ROOT / "README.md",
    DOCS / "Segunda_iteracio.md",
    DOCS / "Torneo_cuatro_circuitos.md",
    DOCS / "Ideas_Mejora.md",
]
LINK_DOCS = [
    ROOT / "README.md",
    ROOT / "CONTRIBUTING.md",
    DOCS / "README.md",
    SOURCE,
    CAPTURES_DOC,
    DOCS / "Segunda_iteracio.md",
    DOCS / "Torneo_cuatro_circuitos.md",
    DOCS / "Ideas_Mejora.md",
    DOCS / "Primera_entrega.md",
]

errors: list[str] = []
IGNORED_PREFIXES = ("http://", "https://", "mailto:", "#")


def fail(message: str) -> None:
    errors.append(message)


def read(path: Path) -> str:
    if not path.exists():
        fail(f"Falta {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


def cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def tables(text: str) -> list[list[str]]:
    found: list[list[str]] = []
    current: list[str] = []
    for line in text.splitlines():
        if line.strip().startswith("|") and line.strip().endswith("|"):
            current.append(line)
        elif current:
            found.append(current)
            current = []
    if current:
        found.append(current)
    return found


def table_with(text: str, header: str) -> list[list[str]]:
    for table in tables(text):
        if header in cells(table[0]):
            return table
    fail(f"No encuentro la tabla con cabecera {header!r} en {SOURCE.name}")
    return []


def data_rows(table: list[list[str]]) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in table[2:]:
        row = cells(line)
        if not row or all(set(cell) <= {"-", ":"} for cell in row):
            continue
        rows.append(row)
    return rows


def ratio(cell: str) -> tuple[int, int] | None:
    match = re.search(r"(\d+)\s*/\s*(\d+)", cell)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def scene_property(text: str, key: str) -> float | None:
    match = re.search(rf"(?m)^{re.escape(key)} = ([0-9.]+)", text)
    if not match:
        fail(f"Falta {key} en una escena")
        return None
    return float(match.group(1))


def checkpoint_count(scene: Path) -> int:
    files = [scene]
    files += [scene.parent / f"{scene.stem}_act{index}.tscn" for index in (1, 2, 3)]
    total = 0
    for path in files:
        if path.exists():
            total += len(
                re.findall(
                    r"(?m)^checkpoint_name = ",
                    path.read_text(encoding="utf-8"),
                )
            )
    return total


def array_size(script: str, name: str) -> int:
    match = re.search(rf"{name}=\((.*?)\)", script, re.DOTALL)
    if not match:
        fail(f"No encuentro el array {name} en run_tests.sh")
        return 0
    return len(re.findall(r"^\s*[A-Za-z_][A-Za-z0-9_]*\s*$", match.group(1), re.MULTILINE))


def circuit_rows(text: str) -> list[list[str]]:
    return [
        row
        for row in data_rows(table_with(text, "Longitud"))
        if len(row) == 8 and row[2].startswith("`")
    ]


def check_circuits(text: str) -> None:
    rows = circuit_rows(text)
    if len(rows) != 5:
        fail(f"La tabla de circuitos tiene {len(rows)} filas; se esperaban 5")

    for row in rows:
        length = int(re.search(r"\d+", row[5]).group())
        medals = [int(value) for value in re.findall(r"\d+", row[7])]
        if len(medals) != 3:
            fail(f"{row[3]}: se esperaban tres medallas en {row[7]!r}")
            continue
        scene = PROJECT / row[4].strip("`")
        if not scene.exists():
            fail(f"No existe la escena {row[4]}")
            continue
        text_scene = read(scene)
        actual_length = scene_property(text_scene, "course_length")
        if actual_length is not None and round(actual_length) != length:
            fail(f"{row[3]}: longitud documentada {length} m; escena {actual_length}")
        for key, expected in zip(
            ("gold_time", "silver_time", "bronze_time"),
            medals,
        ):
            actual = scene_property(text_scene, key)
            if actual is not None and int(actual) != expected:
                fail(f"{row[3]}: {key} documentado {expected}; escena {actual}")
        checkpoints = checkpoint_count(scene)
        expected_checkpoints = int(row[6])
        if checkpoints != expected_checkpoints:
            fail(
                f"{row[3]}: checkpoints documentados {expected_checkpoints}; "
                f"encontrados {checkpoints}"
            )


def check_counts(text: str) -> None:
    counts = {
        row[0]: int(re.search(r"\d+", row[1]).group())
        for row in data_rows(table_with(text, "Cantidad"))
    }
    rows = circuit_rows(text)
    actual = {
        "Circuitos": len(rows),
        "Circuitos del torneo": len([row for row in rows if row[1] == "Torneo"]),
        "Escenas de obstáculo reutilizables": len(
            list((PROJECT / "scenes" / "obstacles").glob("*.tscn"))
        ),
        "Personajes": len(
            re.findall(
                r'"id":',
                read(PROJECT / "scripts" / "character_catalog.gd"),
            )
        ),
        "Cuerpos de personaje": len(
            re.findall(
                r"MODEL_DIR \+",
                read(PROJECT / "scripts" / "character_catalog.gd"),
            )
        ),
        "SFX sintetizados": len(list((PROJECT / "audio" / "sfx").glob("*.wav"))),
        "Tramos de la espiral de Lava Vortex": int(
            re.search(
                r"const V_SEGMENTS := (\d+)",
                read(PROJECT / "scripts" / "levels" / "volcano_kit.gd"),
            ).group(1)
        ),
    }
    for label, value in actual.items():
        if counts.get(label) != value:
            fail(f"{label}: documentado {counts.get(label)}, código {value}")


def check_config(text: str) -> None:
    rows = {
        row[0]: row[1]
        for row in data_rows(table_with(text, "Dato"))
    }
    game = read(PROJECT / "scripts" / "game_session.gd")
    rounds = int(re.search(r"TOTAL_ROUNDS := (\d+)", game).group(1))
    qualifiers = re.search(r"QUALIFIERS_BY_ROUND := \[([^\]]+)\]", game).group(1)
    qualifiers = [int(value) for value in re.findall(r"\d+", qualifiers)]
    bot_initial = int(re.search(r"var bot_count: int = (\d+)", game).group(1))
    bot_max = int(re.search(r"bot_count \+ 1, (\d+)", game).group(1))
    speed = re.search(
        r"func bot_speed_scale\(\) -> float:\s*"
        r"return 1\.0 \+ float\(round - 1\) \* 0\.05",
        game,
    )

    if rows.get("Rondas") != str(rounds):
        fail(f"Rondas: documentadas {rows.get('Rondas')}, código {rounds}")
    if rows.get("Bots iniciales") != str(bot_initial):
        fail(f"Bots iniciales: documentados {rows.get('Bots iniciales')}, código {bot_initial}")
    if rows.get("Bots máximos") != str(bot_max):
        fail(f"Bots máximos: documentados {rows.get('Bots máximos')}, código {bot_max}")
    expected_qualifiers = " → ".join(str(value) for value in qualifiers)
    if rows.get("Plazas que clasifican") != expected_qualifiers:
        fail(
            "Plazas que clasifican: documentadas "
            f"{rows.get('Plazas que clasifican')}, código {expected_qualifiers}"
        )
    if not speed:
        fail("No encuentro el incremento del 5 % en bot_speed_scale()")
    elif "+5 %" not in rows.get("Velocidad de bots por ronda", ""):
        fail("Velocidad de bots: la tabla no documenta +5 %")


def check_verification(text: str) -> None:
    rows = {
        row[0]: row[1]
        for row in data_rows(table_with(text, "Comprobación"))
    }
    suite = read(PROJECT / "tools" / "run_tests.sh")
    suite_count = array_size(suite, "SUITE")
    long_count = array_size(suite, "LONG_SUITE")
    scene_count = len(list((PROJECT / "scenes").rglob("*.tscn")))

    for label, expected in (
        ("Suite obligatoria", suite_count),
        ("Escenas", scene_count),
        ("Tests largos de bots", long_count),
    ):
        row = next(
            (value for key, value in rows.items() if key.startswith(label)),
            "",
        )
        found = ratio(row)
        if found != (expected, expected):
            fail(f"{label}: documentado {row!r}, encontrado {expected}/{expected}")


def check_links() -> None:
    anchors = set(
        re.findall(r'<a id="([^"]+)"', read(SOURCE))
    )
    for path in LINK_DOCS:
        text = read(path)
        for match in re.finditer(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            raw = match.group(1)
            target = raw.split("#", 1)[0]
            if not target or target.startswith(IGNORED_PREFIXES):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                fail(f"Enlace roto en {path.relative_to(ROOT)}: {raw}")
            if target.endswith("Datos_circuitos.md") and "#" in raw:
                if raw.split("#", 1)[1] not in anchors:
                    fail(f"Ancla inexistente en {path.relative_to(ROOT)}: {raw}")
        for match in re.finditer(r'<img[^>]+src="([^"]+)"', text):
            raw = match.group(1)
            if raw.startswith(IGNORED_PREFIXES):
                continue
            if not (path.parent / raw).resolve().exists():
                fail(f"Imagen ausente en {path.relative_to(ROOT)}: {raw}")


def check_captures() -> None:
    captures = sorted((DOCS / "capturas").glob("*.webp"))
    if not captures:
        fail("No hay capturas WebP en documentacion/capturas/")
    for path in captures:
        header = path.read_bytes()[:12]
        if len(header) < 12 or header[:4] != b"RIFF" or header[8:12] != b"WEBP":
            fail(f"La captura {path.name} no es WebP válida")
    linked = set(
        re.findall(r"capturas/([^)\s\"']+\.webp)", read(CAPTURES_DOC))
    )
    if linked != {path.name for path in captures}:
        fail(
            "Las capturas enlazadas en Capturas.md no coinciden con las de "
            "documentacion/capturas/: "
            f"enlazadas {sorted(linked)}, presentes {sorted(path.name for path in captures)}"
        )


def check_repeated_figures(text: str) -> None:
    figures = set()
    for row in circuit_rows(text):
        figures.add(row[5])
        figures.add(row[7])
    for row in data_rows(table_with(text, "Comprobación")):
        found = ratio(row[1])
        if found:
            figures.add(f"{found[0]}/{found[1]}")
    figures.update(
        {
            "17 escenas",
            "10 personajes",
            "20 cuerpos",
            "15 SFX",
            "116 tramos",
            "5 circuitos",
            "4 circuitos",
            "4 rondas",
            "7 bots",
            "11 bots",
        }
    )

    for path in FOUR_DOCS:
        content = read(path)
        for figure in figures:
            if figure and figure in content:
                fail(
                    f"{path.relative_to(ROOT)} repite la cifra {figure!r} "
                    "que vive en Datos_circuitos.md"
                )


def main() -> int:
    text = read(SOURCE)
    check_circuits(text)
    check_counts(text)
    check_config(text)
    check_verification(text)
    check_links()
    check_captures()
    check_repeated_figures(text)

    if errors:
        print("FALLOS DE DOCUMENTACION:")
        for error in errors:
            print(f"  - {error}")
        print("RESULT: FALLIDO")
        return 1
    print("RESULT: TODO OK (docs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
