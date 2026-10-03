"""Collect the character set used by the Web client and emit a font subset.

Scans Dart sources, bundled seed assets and SeedContent for every character
they can render, then writes a de-duplicated charset file for pyftsubset.
Rerun whenever seed content or UI strings change, then regenerate the subset:

    python tool/subset_font.py
    pyftsubset assets/fonts/NotoSansSC.ttf \
        --text-file=build/font-charset.txt \
        --output-file=assets/fonts/NotoSansSC-subset.ttf \
        --no-hinting --desubroutinize
"""

from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "SelahFlutter"
SCAN_DIRS = [ROOT / "lib", ROOT / "assets", REPO / "SeedContent"]
OUT = ROOT / "build" / "font-charset.txt"
SCAN_SUFFIXES = {".dart", ".json", ".txt", ".md", ".csv", ".arb"}


def main() -> None:
    chars: set[str] = set()
    for base in SCAN_DIRS:
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in SCAN_SUFFIXES:
                continue
            try:
                chars.update(path.read_text(encoding="utf-8"))
            except UnicodeDecodeError:
                continue

    chars.update(chr(code) for code in range(0x20, 0x7F))
    chars.update("，。！？：；、「」『』（）【】·…—～％＄（）""''　·…—～")
    chars.discard("\n")
    chars.discard("\r")
    chars.discard("\t")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("".join(sorted(chars)), encoding="utf-8")
    print(f"chars: {len(chars)} -> {OUT}")


if __name__ == "__main__":
    main()
