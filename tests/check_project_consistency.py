import csv
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("pt", "en", "es")


def fail(message: str) -> None:
    raise SystemExit(message)


with (ROOT / "assets/translations.csv").open(encoding="utf-8-sig", newline="") as csv_file:
    reader = csv.DictReader(csv_file)
    if reader.fieldnames != ["keys", *LOCALES]:
        fail(f"Cabeçalho inesperado em assets/translations.csv: {reader.fieldnames}")
    rows = list(reader)

keys = [row["keys"].strip() for row in rows]
if len(keys) != len(set(keys)):
    fail("Há chaves de tradução duplicadas.")

for line_number, row in enumerate(rows, start=2):
    if any(not row.get(field, "").strip() for field in ("keys", *LOCALES)):
        fail(f"Campo vazio na linha {line_number} do catálogo de traduções.")
    placeholder_sets = [re.findall(r"%(?:\d+\$)?[sdif]", row[locale]) for locale in LOCALES]
    if placeholder_sets.count(placeholder_sets[0]) != len(LOCALES):
        fail(f"Placeholders incompatíveis na chave {row['keys']}.")

# The catalog accepts stable IDs and source phrases in any of the three languages.
for locale in LOCALES:
    source_to_target: dict[str, str] = {}
    for row in rows:
        for source in (row["keys"], *(row[source_locale] for source_locale in LOCALES)):
            previous = source_to_target.setdefault(source, row[locale])
            if previous != row[locale]:
                fail(f"Tradução ambígua para {source!r} no idioma {locale}.")

known_messages = set(keys)
for row in rows:
    known_messages.update(row[locale] for locale in LOCALES)

for directory in (ROOT / "scripts", ROOT / "autoload"):
    for gdscript in directory.glob("*.gd"):
        source = gdscript.read_text(encoding="utf-8")
        for message in re.findall(r'\btr\("([^"]+)"\)', source):
            if message not in known_messages:
                fail(f"Texto sem tradução em {gdscript.relative_to(ROOT)}: {message}")

for scene in (ROOT / "scenes").glob("*.tscn"):
    for line_number, line in enumerate(scene.read_text(encoding="utf-8").splitlines(), start=1):
        match = re.match(r'\s*(?:text|placeholder_text|tooltip_text)\s*=\s*"([^"]*)"', line)
        if not match:
            continue
        message = match.group(1)
        if re.search(r"[A-Za-zÀ-ú]", message) and message not in known_messages:
            if message not in {"Bot", "v1.0 (Forward+)", "  ·  v1.0 (Forward+)", "v1.0 Forward+", "💣 BOMBÁSTICO"}:
                fail(f"Texto de cena sem tradução em {scene.relative_to(ROOT)}:{line_number}: {message}")

project = (ROOT / "project.godot").read_text(encoding="utf-8")
features = re.search(r'config/features=PackedStringArray\("(\d+\.\d+)', project)
workflow = (ROOT / ".github/workflows/build.yml").read_text(encoding="utf-8")
engine = re.search(r'GODOT_VERSION:\s*"(\d+\.\d+)', workflow)
if not features or not engine or features.group(1) != engine.group(1):
    fail("A versão principal/secundária do Godot diverge entre project.godot e o CI.")

if "|| true" in workflow:
    fail("O workflow contém uma etapa que mascara erros.")
if "-- --run-test" not in workflow:
    fail("O workflow não executa o autoteste do menu.")
if "res://scenes/lobby.tscn -- --run-test" not in workflow:
    fail("O workflow não executa o autoteste do lobby.")

print(f"Consistência aprovada: {len(rows)} traduções, três idiomas e Godot {engine.group(1)}.")
