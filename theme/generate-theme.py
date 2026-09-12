#!/usr/bin/env python3
"""Regenerate starship.toml, statusline.sh, and ghostty config color blocks
from one theme/palettes/<name>.toml file.

***REMOVED***
***REMOVED***
simple regex rather than pulling in a TOML library, since there's no nesting.

Each generated file has a marked block:
  # BEGIN GENERATED THEME (do not edit; run theme/generate-theme.py)
  ...
  # END GENERATED THEME
Only that block is replaced; everything else in the file is left alone.
"""
import json
import re
import sys
from pathlib import Path

DOTFILES = Path(__file__).resolve().parent.parent
PALETTES_DIR = DOTFILES / "theme" / "palettes"

BEGIN = "BEGIN GENERATED THEME (do not edit; run theme/generate-theme.py)"
END = "END GENERATED THEME"


def parse_palette(path: Path) -> dict:
    colors = {}
    for line in path.read_text().splitlines():
        m = re.match(r'^\s*(\w+)\s*=\s*"(#?[0-9a-fA-F]{6}|\w+)"\s*(#.*)?$', line)
        if m:
            colors[m.group(1)] = m.group(2)
    return colors


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(light_hex: str, dark_hex: str, steps: int) -> list[str]:
    a, b = hex_to_rgb(light_hex), hex_to_rgb(dark_hex)
    return [rgb_to_hex(lerp(a, b, i / (steps - 1))) for i in range(steps)]


def replace_block(text: str, comment_prefix: str, new_body: str) -> str:
    begin_line = f"{comment_prefix} {BEGIN}"
    end_line = f"{comment_prefix} {END}"
    pattern = re.compile(
        re.escape(begin_line) + r".*?" + re.escape(end_line), re.DOTALL
    )
    block = f"{begin_line}\n{new_body}{end_line}"
    if pattern.search(text):
        return pattern.sub(block, text)
    return text.rstrip("\n") + "\n\n" + block + "\n"


STARSHIP_KEYS = ["red", "peach", "yellow", "green", "sapphire", "lavender", "crust"]


def build_derived(colors: dict) -> dict:
    # A palette can specify the six powerline stops directly (as pastel-green
    # does) to be reproduced exactly rather than approximated by a gradient.
    if all(k in colors for k in STARSHIP_KEYS):
        return {k: colors[k] for k in STARSHIP_KEYS}

    light = colors.get("light_foreground") or colors.get("foreground")
    dark = colors.get("muted") or colors.get("accent")
    stops = gradient(light, dark, 6)
    names = ["red", "peach", "yellow", "green", "sapphire", "lavender"]
    derived = dict(zip(names, stops))
    derived["crust"] = colors.get("background", "#000000")
    return derived


def gen_starship(colors: dict, derived: dict) -> str:
    lines = [f'{k} = "{v}"\n' for k, v in derived.items()]
    return "".join(lines)


def rgb_triplet(hex_color: str) -> str:
    r, g, b = hex_to_rgb(hex_color)
    return f"{r};{g};{b}"


def gen_statusline(derived: dict) -> str:
    label_map = [
        ("RED", "red"), ("PEACH", "peach"), ("YELLOW", "yellow"),
        ("GREEN", "green"), ("SAPPHIRE", "sapphire"), ("LAVENDER", "lavender"),
        ("CRUST", "crust"),
    ]
    lines = []
    for var, key in label_map:
        hex_color = derived[key]
        lines.append(f'{var}="{rgb_triplet(hex_color)}"  # {hex_color}\n')
    return "".join(lines)


def pick(colors: dict, *keys: str, default: str = "#000000") -> str:
    for k in keys:
        if k in colors:
            return colors[k]
    return default


def gen_ghostty(colors: dict) -> str:
    background = pick(colors, "background")
    foreground = pick(colors, "foreground")
    bright_foreground = pick(colors, "bright_foreground", "foreground")
    selection_bg = pick(colors, "selection", "lighter_background", default=background)
    selection_fg = foreground

***REMOVED***
***REMOVED***
    muted = pick(colors, "muted", "dark_background", default=background)
    palette = {
        0: background,
        1: pick(colors, "red"),
        2: pick(colors, "green"),
        3: pick(colors, "yellow"),
        4: pick(colors, "blue"),
        5: pick(colors, "magenta"),
        6: pick(colors, "cyan"),
        7: foreground,
        8: muted,
        9: pick(colors, "bright_red", "red"),
        10: pick(colors, "bright_green", "green"),
        11: pick(colors, "bright_yellow", "yellow"),
        12: pick(colors, "bright_blue", "blue"),
        13: pick(colors, "bright_magenta", "magenta"),
        14: pick(colors, "bright_cyan", "cyan"),
        15: bright_foreground,
    }
    lines = [
        f'background = "{background}"\n',
        f'foreground = "{foreground}"\n',
        f'cursor-color = "{bright_foreground}"\n',
        f'selection-background = "{selection_bg}"\n',
        f'selection-foreground = "{selection_fg}"\n',
    ]
    for i in range(16):
        lines.append(f"palette = {i}={palette[i]}\n")
    return "".join(lines)


TOKEN_SCOPES = [
    ("Comments", ["comment"], "dark_foreground"),
    ("Strings", ["string"], "green"),
    ("Numbers, booleans, constants", ["constant.numeric", "constant.language", "constant.character"], "orange"),
    ("Keywords, storage, operators", ["keyword", "storage", "keyword.operator"], "magenta"),
    ("Functions", ["entity.name.function", "support.function"], "blue"),
    ("Types, classes", ["entity.name.type", "entity.name.class", "support.type", "support.class"], "yellow"),
    ("Variables, parameters", ["variable", "variable.parameter"], "foreground"),
    ("Tags (markup/html)", ["entity.name.tag"], "red"),
    ("Attributes", ["entity.other.attribute-name"], "cyan"),
]


def gen_vscode_theme(colors: dict, theme_name: str) -> tuple[str, str]:
    """Returns (package.json, themes/dotfiles.json) for an unpacked VS Code
    theme extension. VS Code/Cursor themes are contributed by extensions, so
    this writes a minimal one and install.sh symlinks it into each app's
    extensions dir, rather than trying to override colors via settings.json.
    """
    background = pick(colors, "background")
    foreground = pick(colors, "foreground")
    bright_fg = pick(colors, "bright_foreground", "foreground")
    dark_bg = pick(colors, "dark_background", default=background)
    darker_bg = pick(colors, "darker_background", default=dark_bg)
    lighter_bg = pick(colors, "lighter_background", default=background)
    selection = pick(colors, "selection", "lighter_background", default=lighter_bg)
    accent = pick(colors, "accent", "blue")
    muted = pick(colors, "muted", "dark_foreground", default=foreground)
    is_dark = colors.get("mode", "dark") != "light"

    ansi = {
        "red": pick(colors, "red"), "green": pick(colors, "green"),
        "yellow": pick(colors, "yellow"), "blue": pick(colors, "blue"),
        "magenta": pick(colors, "magenta"), "cyan": pick(colors, "cyan"),
        "brightRed": pick(colors, "bright_red", "red"),
        "brightGreen": pick(colors, "bright_green", "green"),
        "brightYellow": pick(colors, "bright_yellow", "yellow"),
        "brightBlue": pick(colors, "bright_blue", "blue"),
        "brightMagenta": pick(colors, "bright_magenta", "magenta"),
        "brightCyan": pick(colors, "bright_cyan", "cyan"),
    }

    theme_colors = {
        "editor.background": background,
        "editor.foreground": foreground,
        "editorLineNumber.foreground": muted,
        "editorLineNumber.activeForeground": bright_fg,
        "editor.lineHighlightBackground": dark_bg,
        "editor.selectionBackground": selection,
        "editorCursor.foreground": bright_fg,
        "editorWhitespace.foreground": muted,
        "editorIndentGuide.background1": dark_bg,
        "editorIndentGuide.activeBackground1": muted,
        "sideBar.background": darker_bg,
        "sideBar.foreground": foreground,
        "sideBarTitle.foreground": foreground,
        "activityBar.background": darker_bg,
        "activityBar.foreground": foreground,
        "activityBar.inactiveForeground": muted,
        "statusBar.background": darker_bg,
        "statusBar.foreground": foreground,
        "titleBar.activeBackground": darker_bg,
        "titleBar.activeForeground": foreground,
        "titleBar.inactiveBackground": darker_bg,
        "titleBar.inactiveForeground": muted,
        "tab.activeBackground": background,
        "tab.activeForeground": bright_fg,
        "tab.inactiveBackground": darker_bg,
        "tab.inactiveForeground": muted,
        "tab.border": darker_bg,
        "panel.background": darker_bg,
        "panel.border": dark_bg,
        "input.background": dark_bg,
        "input.foreground": foreground,
        "dropdown.background": dark_bg,
        "focusBorder": accent,
        "list.activeSelectionBackground": selection,
        "list.hoverBackground": dark_bg,
        "badge.background": accent,
        "badge.foreground": background,
        "button.background": accent,
        "button.foreground": background,
        "terminal.background": background,
        "terminal.foreground": foreground,
        "terminal.ansiRed": ansi["red"],
        "terminal.ansiGreen": ansi["green"],
        "terminal.ansiYellow": ansi["yellow"],
        "terminal.ansiBlue": ansi["blue"],
        "terminal.ansiMagenta": ansi["magenta"],
        "terminal.ansiCyan": ansi["cyan"],
        "terminal.ansiBrightRed": ansi["brightRed"],
        "terminal.ansiBrightGreen": ansi["brightGreen"],
        "terminal.ansiBrightYellow": ansi["brightYellow"],
        "terminal.ansiBrightBlue": ansi["brightBlue"],
        "terminal.ansiBrightMagenta": ansi["brightMagenta"],
        "terminal.ansiBrightCyan": ansi["brightCyan"],
    }

    token_colors = [
        {
            "name": label,
            "scope": scopes,
            "settings": {"foreground": pick(colors, key, default=foreground)},
        }
        for label, scopes, key in TOKEN_SCOPES
    ]

    theme_json = {
        "name": "Dotfiles",
        "type": "dark" if is_dark else "light",
        "colors": theme_colors,
        "tokenColors": token_colors,
    }

    package_json = {
        "name": "dotfiles-theme",
        "displayName": "Dotfiles Theme",
        "description": f"Generated from theme/palettes/{theme_name}.toml; regenerate via theme/generate-theme.py",
        "version": "0.0.1",
        "publisher": "dotfiles",
        "engines": {"vscode": "^1.50.0"},
        "categories": ["Themes"],
        "contributes": {
            "themes": [
                {
                    "label": "Dotfiles",
                    "uiTheme": "vs-dark" if is_dark else "vs",
                    "path": "./themes/dotfiles.json",
                }
            ]
        },
    }

    return (
        json.dumps(package_json, indent=2) + "\n",
        json.dumps(theme_json, indent=2) + "\n",
    )


def editor_user_dir(app_name: str) -> Path:
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / app_name / "User"
    # Linux paths (VS Code: Code, Cursor: Cursor)
    return Path.home() / ".config" / app_name / "User"


def set_editor_theme(app_name: str) -> None:
    user_dir = editor_user_dir(app_name)
    if not user_dir.parent.exists():
        return  # app not installed
    settings_path = user_dir / "settings.json"
    user_dir.mkdir(parents=True, exist_ok=True)
    settings = {}
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text())
        except json.JSONDecodeError:
            print(f"Skipping {settings_path}: not valid JSON", file=sys.stderr)
            return
    settings["workbench.colorTheme"] = "Dotfiles"
    settings_path.write_text(json.dumps(settings, indent=2) + "\n")
    print(f"Set workbench.colorTheme in {settings_path}")


def apply(path: Path, comment_prefix: str, body: str) -> None:
    text = path.read_text() if path.exists() else ""
    new_text = replace_block(text, comment_prefix, body)
    path.write_text(new_text)
    print(f"Updated {path.relative_to(DOTFILES)}")


def main() -> None:
    theme_name = sys.argv[1] if len(sys.argv) > 1 else "pastel-green"
    palette_path = PALETTES_DIR / f"{theme_name}.toml"
    if not palette_path.exists():
        available = sorted(p.stem for p in PALETTES_DIR.glob("*.toml"))
        print(f"Unknown theme '{theme_name}'. Available: {', '.join(available)}", file=sys.stderr)
        sys.exit(1)

    colors = parse_palette(palette_path)
    derived = build_derived(colors)

    apply(DOTFILES / "config" / "starship.toml", "#", gen_starship(colors, derived))
    apply(DOTFILES / "config" / "claude" / "statusline.sh", "#", gen_statusline(derived))
    apply(DOTFILES / "config" / "ghostty" / "config", "#", gen_ghostty(colors))

    ext_dir = DOTFILES / "config" / "vscode" / "dotfiles-theme"
    themes_dir = ext_dir / "themes"
    themes_dir.mkdir(parents=True, exist_ok=True)
    package_json, theme_json = gen_vscode_theme(colors, theme_name)
    (ext_dir / "package.json").write_text(package_json)
    (themes_dir / "dotfiles.json").write_text(theme_json)
    print(f"Updated {ext_dir.relative_to(DOTFILES)}")

    set_editor_theme("Code")
    set_editor_theme("Cursor")

    (DOTFILES / "theme" / "current").write_text(theme_name + "\n")
    print(f"Theme set to: {theme_name}")


if __name__ == "__main__":
    main()
