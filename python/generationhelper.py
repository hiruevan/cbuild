import os
from pathlib import Path
from string import Template

TEMPLATE_DIR = Path(__file__).parent.parent / "templates"


def load_template(name: str) -> Template:
    return Template((TEMPLATE_DIR / name).read_text(encoding="utf-8"))


def load_file(path):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    full_path = os.path.normpath(os.path.join(script_dir, path))

    try:
        # utf-8-sig strips a leading BOM if present
        with open(full_path, 'r', encoding='utf-8-sig') as file:
            return file.read()
    except FileNotFoundError:
        raise FileNotFoundError(f"Error: The file '{full_path}' was not found.")
    except PermissionError:
        raise PermissionError(f"Error: Permission denied to read '{full_path}'.")


def write_if_changed(path: Path, content: str) -> None:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return  # preserves mtime so the C build doesn't rebuild needlessly
    path.write_text(content, encoding="utf-8")


def fail(message, line=None):
    location = f"Line {line}: " if line else ""
    raise ValueError(location + message)