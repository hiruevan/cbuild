
import re
import sys

from generationhelper import *
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from generationhelper import *


# --------------------------------------------------
# Platform configuration
# --------------------------------------------------

PLATFORMS = {
    "cal": ["CALCULATOR"],
    "win": ["KEYBOARD", "GAMEPAD"],
    "mac": ["KEYBOARD", "GAMEPAD"],
    "lnx": ["KEYBOARD", "GAMEPAD"],
    "lnx-x86_64": ["KEYBOARD", "GAMEPAD"],
    "lnx-aarch64": ["KEYBOARD", "GAMEPAD"],
    "lnx-armhf": ["KEYBOARD", "GAMEPAD"],
    "webp": ["KEYBOARD", "GAMEPAD"],
    "android": ["MOBILE"],
    "ios": ["MOBILE"],
}

VALID_BLOCKS = {
    "CALCULATOR",
    "KEYBOARD",
    "GAMEPAD",
    "MOBILE",
}


# --------------------------------------------------
# Gamepad support (SDL2 GameController API)
# --------------------------------------------------

PAD_BUTTONS = {
    "A": "A", "B": "B", "X": "X", "Y": "Y",
    "Plus": "START", "Start": "START",
    "Minus": "BACK", "Back": "BACK", "Select": "BACK",
    "Home": "GUIDE",
    "Up": "DPAD_UP", "Down": "DPAD_DOWN",
    "Left": "DPAD_LEFT", "Right": "DPAD_RIGHT",
    "L": "LEFTSHOULDER", "R": "RIGHTSHOULDER",
    "L_Stick": "LEFTSTICK", "R_Stick": "RIGHTSTICK",
}

PAD_TRIGGERS = {
    "ZL": "SDL_CONTROLLER_AXIS_TRIGGERLEFT",
    "ZR": "SDL_CONTROLLER_AXIS_TRIGGERRIGHT",
}

# Sign applied to the raw SDL axis value. SDL's Y axis grows downward,
# so "Pos_Y" (up) is the negative direction of the raw axis.
PAD_AXIS_SIGN = {
    ("Pos", "X"): "+1",
    ("Neg", "X"): "-1",
    ("Pos", "Y"): "-1",
    ("Neg", "Y"): "+1",
}

GAMEPAD_HELPERS = load_file("../templates/gamepad.c")

# --------------------------------------------------
# Backend definitions
# --------------------------------------------------

ANY_KEY = "AnyKey"

@dataclass(frozen=True)
class Backend:
    block: str
    includes: str
    scan_prologue: str
    key_to_expr: Callable[[str], str]
    helpers: str = ""
    prompt: str = ""
    any_expr: str = ""

PROMPT_COMMON = load_file("../templates/prompt_common.c")

BACKENDS = {
    "CALCULATOR": Backend(
        block="CALCULATOR",
        includes="#include <keypadc.h>",
        scan_prologue="    kb_Scan();",
        key_to_expr=lambda b: f"kb_IsDown({calculator_key(b)})",
        prompt=load_file("../templates/prompt_calculator.c"),
        any_expr="kb_AnyKey()"
    ),

    "KEYBOARD": Backend(
        block="KEYBOARD",
        includes='#include <SDL.h>\n#include "keypadc.h"',
        scan_prologue=(
            "    kb_Scan();\n"
            "    const Uint8 *keyboard = SDL_GetKeyboardState(NULL);"
        ),
        key_to_expr=lambda b: f"keyboard[{keyboard_key(b)}]",
        prompt=load_file("../templates/prompt_keyboard.c"),
        any_expr="_keyboard_any()"
    ),
    "GAMEPAD": Backend(
        block="GAMEPAD",
        includes="#include <SDL.h>\n#include <stdbool.h>",
        helpers=GAMEPAD_HELPERS,
        scan_prologue=(
            "    _pad_refresh();\n"
            "    SDL_GameControllerUpdate();"
        ),
        key_to_expr=lambda b: gamepad_key(b),
        prompt=load_file("../templates/prompt_gamepad.c"),
        any_expr="_pad_any()"
    ),
}


# --------------------------------------------------
# Configuration parser
# --------------------------------------------------

def parse_config(path):
    with open(path, "r", encoding="utf-8-sig") as file:
        lines = file.readlines()

    definitions = []
    blocks = {}

    current_block = None
    current_action = None

    for number, raw in enumerate(lines, 1):
        line = raw.split("#", 1)[0].strip()

        if not line:
            continue

        # Action declaration
        if line.startswith("DEF "):
            if current_block:
                fail(
                    "DEF declarations must appear outside blocks.",
                    number,
                )

            action = line[4:].strip()

            if not re.fullmatch(r"[A-Za-z_]\w*", action):
                fail(f"Invalid action name '{action}'.", number)

            if action in definitions:
                fail(f"Duplicate action '{action}'.", number)

            if action == ANY_KEY:
                fail(f"'{ANY_KEY}' is reserved.", number)

            definitions.append(action)
            continue

        # Block declaration
        if line.endswith("{"):
            block = line[:-1].strip().upper()

            if block not in VALID_BLOCKS:
                fail(f"Unknown platform block '{block}'.", number)

            if current_block:
                fail("Nested blocks are not supported.", number)

            if block in blocks:
                fail(f"Duplicate block '{block}'.", number)

            current_block = block
            blocks[block] = {}
            current_action = None
            continue

        # Block closing
        if line == "}":
            if not current_block:
                fail("Unexpected closing brace.", number)

            current_block = None
            current_action = None
            continue

        if not current_block:
            fail("Unexpected content outside a platform block.", number)

        # Action properties
        if line.startswith("."):
            if not current_action:
                fail("Property has no preceding action.", number)

            match = re.fullmatch(
                r"\.(name|pos)\s*=\s*(.+)",
                line,
            )

            if not match:
                fail(f"Invalid property '{line}'.", number)

            prop, value = match.groups()
            action = blocks[current_block][current_action]

            if prop in action:
                fail(f"Duplicate property '{prop}'.", number)

            if prop == "name":
                if not (
                    len(value) >= 2
                    and value[0] == '"'
                    and value[-1] == '"'
                ):
                    fail(".name must be enclosed in quotes.", number)

                action["name"] = value[1:-1]

            elif prop == "pos":
                match = re.fullmatch(
                    r"([+-]?\d+(?:\.\d+)?)\s*,\s*"
                    r"([+-]?\d+(?:\.\d+)?)",
                    value,
                )

                if not match:
                    fail(".pos must contain two numbers.", number)

                x, y = map(float, match.groups())

                if not (0 <= x <= 1 and 0 <= y <= 1):
                    fail(
                        ".pos coordinates must be between 0 and 1.",
                        number,
                    )

                action["pos"] = (x, y)

            continue

        # Action assignment
        match = re.fullmatch(
            r"([A-Za-z_]\w*)\s*=\s*(.+)",
            line,
        )

        if not match:
            fail(f"Invalid assignment '{line}'.", number)

        action_name, raw_bindings = match.groups()

        if action_name in blocks[current_block]:
            fail(
                f"Duplicate assignment for '{action_name}'.",
                number,
            )

        bindings = [
            item.strip()
            for item in raw_bindings.split(",")
        ]

        if not bindings or any(not item for item in bindings):
            fail("Invalid empty binding.", number)

        if "NONE" in bindings and len(bindings) != 1:
            fail(
                "NONE cannot be combined with other bindings.",
                number,
            )

        blocks[current_block][action_name] = {
            "bindings": bindings
        }

        current_action = action_name

    # Validate block closure
    if current_block:
        fail(f"Unclosed {current_block} block.")

    if not definitions:
        fail("No DEF declarations found.")

    # Validate every block against global definitions
    for block_name, actions in blocks.items():

        for action in actions:
            if action not in definitions:
                fail(
                    f"'{action}' is assigned in {block_name}, "
                    "but has no DEF declaration."
                )

        for definition in definitions:
            if definition not in actions:
                fail(
                    f"'{definition}' has no assignment in {block_name}. "
                    "Use NONE if intentionally unbound."
                )

    return definitions, blocks


# --------------------------------------------------
# Key mapping
# --------------------------------------------------

def calculator_key(binding):
    if not binding.startswith("Key_"):
        fail(
            f"'{binding}' is not a calculator key. "
            "Expected a Key_ binding."
        )

    key = binding[4:]

    special = {
        "2nd": "2nd",
        "Alpha": "Alpha",
        "Prgm": "Prgm",
    }

    key = special.get(key, key)

    return "kb_Key" + key


def keyboard_key(binding):
    if not binding.startswith("Key_"):
        fail(
            f"'{binding}' is not a keyboard key. "
            "Expected a Key_ binding."
        )

    key = binding[4:]

    special = {
        "Arrow_Up": "UP",
        "Arrow_Down": "DOWN",
        "Arrow_Left": "LEFT",
        "Arrow_Right": "RIGHT",

        "Esc": "ESCAPE",
        "Del": "DELETE",
        "Return": "RETURN",
        "Enter": "RETURN",
        "Backspace": "BACKSPACE",

        "Space": "SPACE",
        "Tab": "TAB",
        "CapsLock": "CAPSLOCK",

        "Left_Shift": "LSHIFT",
        "Right_Shift": "RSHIFT",
        "Left_Ctrl": "LCTRL",
        "Right_Ctrl": "RCTRL",
        "Left_Alt": "LALT",
        "Right_Alt": "RALT",

        "Minus": "MINUS",
        "Equals": "EQUALS",
        "Left_Bracket": "LEFTBRACKET",
        "Right_Bracket": "RIGHTBRACKET",
        "Backslash": "BACKSLASH",
        "Semicolon": "SEMICOLON",
        "Apostrophe": "APOSTROPHE",
        "Grave": "GRAVE",
        "Comma": "COMMA",
        "Period": "PERIOD",
        "Slash": "SLASH",

        "KP_Plus": "KP_PLUS",
        "KP_Minus": "KP_MINUS",
        "KP_Multiply": "KP_MULTIPLY",
        "KP_Divide": "KP_DIVIDE",
        "KP_Enter": "KP_ENTER",
        "KP_Period": "KP_PERIOD",
    }

    # Letters
    if re.fullmatch(r"[A-Za-z]", key):
        return f"SDL_SCANCODE_{key.upper()}"

    # Number row
    if re.fullmatch(r"[0-9]", key):
        return f"SDL_SCANCODE_{key}"

    # Function keys
    if re.fullmatch(r"F([1-9]|1[0-9]|2[0-4])", key):
        return f"SDL_SCANCODE_{key.upper()}"

    # Numeric keypad
    if re.fullmatch(r"KP_[0-9]", key):
        return f"SDL_SCANCODE_{key.upper()}"

    if key in special:
        return f"SDL_SCANCODE_{special[key]}"

    fail(
        f"Unknown keyboard key '{binding}'. "
        # "Add its SDL scancode mapping to keyboard_key()."
    )


def gamepad_key(binding):
    if not binding.startswith("Pad_"):
        fail(
            f"'{binding}' is not a gamepad binding. "
            "Expected a Pad_ binding."
        )

    key = binding[4:]

    # Buttons and d-pad
    if key in PAD_BUTTONS:
        return f"_pad_button(SDL_CONTROLLER_BUTTON_{PAD_BUTTONS[key]})"

    # Analog triggers (treated as buttons)
    if key in PAD_TRIGGERS:
        return f"_pad_axis({PAD_TRIGGERS[key]}, +1)"

    # Stick directions, e.g. Left_Pos_Y
    match = re.fullmatch(r"(Left|Right)_(Pos|Neg)_([XY])", key)

    if match:
        stick, direction, axis = match.groups()
        sdl_axis = f"SDL_CONTROLLER_AXIS_{stick.upper()}{axis}"
        sign = PAD_AXIS_SIGN[(direction, axis)]

        return f"_pad_axis({sdl_axis}, {sign})"

    fail(f"Unknown gamepad binding '{binding}'.")

# --------------------------------------------------
# C rendering helpers
# --------------------------------------------------

def c_string(value):
    return (
        '"'
        + value.replace("\\", "\\\\")
                .replace('"', '\\"')
                .replace("\n", "\\n")
        + '"'
    )

def action_label(action, actions):
    if action == ANY_KEY:
        return "Anything"

    return display_name(action, actions[action])

def display_name(action, data):
    if data.get("name"):
        return data["name"]

    first = data["bindings"][0]

    if first == "NONE":
        return action
    else: 
        first = data["bindings"][0]

        return (
            action
            if first == "NONE"
            else re.sub(r"^(Key|Pad|Touch)_", "", first)
        )


# --------------------------------------------------
# C code generation
# --------------------------------------------------

def render_header(definitions):
    all_actions = definitions + [ANY_KEY]

    fields = "\n".join(
        f"    InputAction {action};"
        for action in all_actions
    )

    return load_template("input.h").substitute(
        action_fields=fields,
        action_count=len(all_actions),
    )


def render_source(definitions, blocks, backends):
    count = len(backends)
    all_actions = definitions + [ANY_KEY]

    # Merge includes (deduplicated, order preserved) and helper code
    include_lines = []

    for backend in backends:
        for line in backend.includes.splitlines():
            if line.strip() and line not in include_lines:
                include_lines.append(line)

    if any(b.prompt for b in backends) and "#include <graphx.h>" not in include_lines:
            include_lines.append("#include <graphx.h>")

    includes = "\n".join(include_lines)

    helpers = [b.helpers for b in backends if b.helpers]

    if helpers:
        includes += "\n\n" + "\n\n".join(helpers)

    # Merge scan prologues (deduplicated line by line)
    prologue_lines = []

    for backend in backends:
        for line in backend.scan_prologue.splitlines():
            if line not in prologue_lines:
                prologue_lines.append(line)

    prologue_lines.append(
        f"    bool _input_dev_active[{count}] = {{false}};"
    )

    # Initial names come from the first (primary) backend
    primary = blocks[backends[0].block]

    inits = "\n".join(
        f"    .{action} = "
        f"{{{index}, {c_string(action_label(action, primary))}}},"
        for index, action in enumerate(all_actions)
    )

    # Per-backend name tables, plus the function that swaps them in
    support = []
    table_names = []

    for backend in backends:
        table = f"_input_names_{backend.block.lower()}"
        table_names.append(table)

        entries = ",\n".join(
            "    " + c_string(action_label(action, blocks[backend.block]))
            for action in all_actions
        )

        support.append(
            f"static const char *const {table}[INPUT_ACTION_COUNT] = {{\n"
            f"{entries}\n"
            f"}};"
        )

    setters = "\n".join(
        f"    INPUT.{action}.name = names[{index}];"
        for index, action in enumerate(all_actions)
    )

    support.append(
        f"static const char *const *const _input_name_sets[{count}] = {{\n"
        + ",\n".join(f"    {t}" for t in table_names)
        + "\n};\n\n"
        "static int _input_device = 0;\n"
        f"static bool _input_dev_was_active[{count}] = {{0}};\n\n"
        "static void _input_set_device(int device) {\n"
        "    const char *const *names = _input_name_sets[device];\n"
        "    _input_device = device;\n"
        f"{setters}\n"
        "}"
    )

    support.append(render_prompt(backends))

    # Per action: evaluate each backend separately so we know which
    # device produced the input, then OR them for the action state
    body = []

    for index, action in enumerate(all_actions):
        lines = []
        flags = []

        for b_index, backend in enumerate(backends):
            if action == ANY_KEY:
                tests = [backend.any_expr] if backend.any_expr else []
            else:
                bindings = blocks[backend.block][action]["bindings"]

                tests = (
                    []
                    if bindings == ["NONE"]
                    else [backend.key_to_expr(b) for b in bindings]
                )

            expr = " || ".join(tests) or "false"

            lines.append(f"        bool k{b_index} = ({expr});")
            lines.append(
                f"        _input_dev_active[{b_index}] |= k{b_index};"
            )
            flags.append(f"k{b_index}")


        body.append(
            "    {\n"
            + "\n".join(lines) + "\n"
            f"        bool now = {' || '.join(flags)};\n"
            f"        _input_pressed[{index}] = "
            f"now && !_input_down[{index}];\n"
            f"        _input_down[{index}] = now;\n"
            "    }"
        )

    # Switch names when a device newly becomes active
    epilogue = (
        f"    for (int i = 0; i < {count}; i++) {{\n"
        "        if (_input_dev_active[i] && !_input_dev_was_active[i]\n"
        "            && i != _input_device)\n"
        "            _input_set_device(i);\n"
        "\n"
        "        _input_dev_was_active[i] = _input_dev_active[i];\n"
        "    }"
    )

    return load_template("input.c").substitute(
        includes=includes,
        action_inits=inits,
        device_support="\n\n".join(support),
        scan_prologue="\n".join(prologue_lines),
        scan_body="\n".join(body),
        scan_epilogue=epilogue,
    )

def render_prompt(backends):
    impls = [b for b in backends if b.prompt]

    if not impls:
        return (
            "const char *TextPrompt(const char *txt, int maxChars)\n"
            "{\n    (void)txt;\n    (void)maxChars;\n    return NULL;\n}"
        )

    # A backend without its own prompt falls back to the first one that has one
    cases = "\n".join(
        f"        case {i}: result = "
        f"_prompt_{(b if b.prompt else impls[0]).block.lower()}(txt, maxChars); break;"
        for i, b in enumerate(backends)
    )

    return (
        PROMPT_COMMON + "\n\n"
        + "\n\n".join(b.prompt for b in impls) + "\n\n"
        + "const char *TextPrompt(const char *txt, int maxChars)\n{\n"
          "    const char *result = NULL;\n\n"
          "    if (maxChars <= 0 || maxChars > INPUT_PROMPT_MAX)\n"
          "        maxChars = INPUT_PROMPT_MAX;\n\n"
          "    gfx_SetColor(_prompt_fg);\n"
          "    gfx_SetTextFGColor(_prompt_fg);\n"
          "    gfx_SetTextBGColor(_prompt_bg);\n"
          "    gfx_SetTextTransparentColor(_prompt_tp());\n\n"
          "    switch (_input_device)\n    {\n"
          f"{cases}\n"
          "    }\n\n"
          "    gfx_SetColor(_rest_color);\n"
          "    gfx_SetTextFGColor(_rest_fg);\n"
          "    gfx_SetTextBGColor(_rest_bg);\n"
          "    gfx_SetTextTransparentColor(_rest_tp);\n\n"
          "    Input_Scan();\n"
          "    Input_Scan();\n\n"
          "    return result;\n}"
    )

# --------------------------------------------------
# Output generation
# --------------------------------------------------

def generate_placeholder(output_dir):
    out = Path(output_dir or ".")
    out.mkdir(parents=True, exist_ok=True)

    content = "\n".join([
        "// Generated by cbuild. Do not edit.",
        "// Placeholder input.h file "
        "([ERROR] platform not implemented)",
        "",
    ])

    write_if_changed(out / "input.h", content)


def generate(backend_names, definitions, blocks, output_dir):
    backends = []

    for name in backend_names:
        if name not in BACKENDS:
            fail(f"Unknown backend '{name}'.")

        backend = BACKENDS[name]

        if backend.block not in blocks:
            fail(f"Missing {backend.block} block.")

        backends.append(backend)

    out = Path(output_dir or ".")
    out.mkdir(parents=True, exist_ok=True)

    write_if_changed(
        out / "input.h",
        render_header(definitions),
    )

    write_if_changed(
        out / "input.c",
        render_source(definitions, blocks, backends),
    )


# --------------------------------------------------
# Platform generation
# --------------------------------------------------

def generate_platform(platform, definitions, blocks, output_dir):
    if platform not in PLATFORMS:
        fail(f"Unsupported platform '{platform}'.")

    implemented = []

    for name in PLATFORMS[platform]:
        if name in BACKENDS:
            implemented.append(name)
        else:
            print(
                f"[Warning] The {name.lower()} input backend "
                f"for {platform} has not been implemented yet."
            )

    if not implemented:
        generate_placeholder(output_dir)
        return

    for name in implemented:
        print(f"    - {name.lower()}")

    generate(implemented, definitions, blocks, output_dir)


# --------------------------------------------------
# Main
# --------------------------------------------------

def main():
    if len(sys.argv) != 4:
        print(
            "Usage: generateinputs.py "
            "config.cfg output_dir platform"
        )
        sys.exit(1)

    config = sys.argv[1]
    output = sys.argv[2]
    platform = sys.argv[3].lower()

    if platform not in PLATFORMS:
        fail(f"Unsupported platform '{platform}'.")

    definitions, blocks = parse_config(config)

    generate_platform(
        platform,
        definitions,
        blocks,
        output,
    )


if __name__ == "__main__":
    try:
        main()

    except (ValueError, OSError) as error:
        print(
            f"Input generation failed: {error}",
            file=sys.stderr,
        )
        sys.exit(1)
