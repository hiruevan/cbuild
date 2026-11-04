
import os
import re
import sys


# --------------------------------------------------
# Configuration parser
# --------------------------------------------------

PLATFORMS = {
    "cal": ["CALCULATOR"],
    "win": ["KEYBOARD", "GAMEPAD"],
    "mac": ["KEYBOARD", "GAMEPAD"],
    "lnx": ["KEYBOARD", "GAMEPAD"],
    "lnx-x86_64": ["KEYBOARD", "GAMEPAD"],
    "lnx-aarch64": ["KEYBOARD", "GAMEPAD"],
    "lnx-armhf": ["KEYBOARD", "GAMEPAD"],
    "android": ["MOBILE"],
    "ios": ["MOBILE"],
}

VALID_BLOCKS = {
    "CALCULATOR",
    "KEYBOARD",
    "GAMEPAD",
    "MOBILE",
}

def fail(message, line=None):
    location = f"Line {line}: " if line else ""
    raise ValueError(location + message)


def parse_config(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        lines = f.readlines()

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
                fail("DEF declarations must appear outside blocks.", number)

            action = line[4:].strip()

            if not re.fullmatch(r"[A-Za-z_]\w*", action):
                fail(f"Invalid action name '{action}'.", number)

            if action in definitions:
                fail(f"Duplicate action '{action}'.", number)

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

        if line == "}":
            if not current_block:
                fail("Unexpected closing brace.", number)

            current_block = None
            current_action = None
            continue

        if not current_block:
            fail("Unexpected content outside a platform block.", number)

        # Optional action properties
        if line.startswith("."):
            if not current_action:
                fail("Property has no preceding action.", number)

            match = re.fullmatch(
                r"\.(name|pos)\s*=\s*(.+)",
                line
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
                    value
                )

                if not match:
                    fail(".pos must contain two numbers.", number)

                x, y = map(float, match.groups())

                if not (0 <= x <= 1 and 0 <= y <= 1):
                    fail(".pos coordinates must be between 0 and 1.", number)

                action["pos"] = (x, y)

            continue

        # Action assignment
        match = re.fullmatch(
            r"([A-Za-z_]\w*)\s*=\s*(.+)",
            line
        )

        if not match:
            fail(f"Invalid assignment '{line}'.", number)

        action_name, raw_bindings = match.groups()

        if action_name in blocks[current_block]:
            fail(f"Duplicate assignment for '{action_name}'.", number)

        bindings = [
            item.strip()
            for item in raw_bindings.split(",")
        ]

        if not bindings or any(not item for item in bindings):
            fail("Invalid empty binding.", number)

        if "NONE" in bindings and len(bindings) != 1:
            fail("NONE cannot be combined with other bindings.", number)

        blocks[current_block][action_name] = {
            "bindings": bindings
        }

        current_action = action_name

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


# --- Placeholder Backend ---
def generate_placeholder(output_dir):
    lines = [
        "// Generated by cbuild. Do not edit.",
        "// Placeholder input.h file ([ERROR] platform not implemented)",
        ]

    os.makedirs(output_dir or ".", exist_ok=True)
    
    outputs = {
            os.path.join(output_dir, "input.h"): "\n".join(lines)
    }
    
    for path, content in outputs.items():
            if not os.path.exists(path):
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
            else:
                with open(path, "r", encoding="utf-8") as f:
                    old = f.read()
    
                if old != content:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(content)


# --------------------------------------------------
# Calculator backend
# --------------------------------------------------

def calculator_key(binding):
    if not binding.startswith("Key_"):
        fail(
            f"'{binding}' is not a calculator key. "
            "Expected a Key_ binding."
        )

    key = binding[4:]

    # Match the names in keypadc.h
    special = {
        "2nd": "2nd",
        "Alpha": "Alpha",
        "Prgm": "Prgm",
    }

    key = special.get(key, key)

    return "kb_Key" + key


def c_string(value):
    return (
        '"'
        + value.replace("\\", "\\\\")
                .replace('"', '\\"')
                .replace("\n", "\\n")
        + '"'
    )


def generate_calculator(definitions, blocks, output_dir):
    if "CALCULATOR" not in blocks:
        fail("Missing CALCULATOR block.")

    actions = blocks["CALCULATOR"]

    header_lines = [
        "// Generated by cbuild. Do not edit.",
        "#pragma once",
        "",
        "#include <stdint.h>",
        "#include <stdbool.h>",
        "",
        "typedef struct {",
        "    uint8_t id;",
        "    const char *name;",
        "} InputAction;",
        "",
        "typedef struct {",
    ]

    for action in definitions:
        header_lines.append(f"    InputAction {action};")

    header_lines += [
        "} InputBindings;",
        "",
        "extern const InputBindings INPUT;",
        "",
        f"#define INPUT_ACTION_COUNT {len(definitions)}",
        "",
        "void Input_Scan(void);",
        "bool KeyDown(InputAction action);",
        "bool KeyJustPressed(InputAction action);",
        "",
    ]

    # === Generate input.c ===

    source_lines = [
        "// Generated by cbuild. Do not edit.",
        "",
        '#include "input.h"',
        "#include <keypadc.h>",
        "",
        "const InputBindings INPUT = {",
    ]

    for index, action in enumerate(definitions):
        data = actions[action]
        bindings = data["bindings"]

        name = data.get("name")

        if not name:
            name = (
                bindings[0].replace("Key_", "")
                if bindings[0] != "NONE"
                else action
            )

        source_lines.append(
            f"    .{action} = {{{index}, {c_string(name)}}},"
        )

    source_lines += [
        "};",
        "",
        "static bool _input_down[INPUT_ACTION_COUNT] = {0};",
        "static bool _input_pressed[INPUT_ACTION_COUNT] = {0};",
        "",
        "void Input_Scan(void) {",
        "    kb_Scan();",
    ]

    for index, action in enumerate(definitions):
        bindings = actions[action]["bindings"]

        tests = []

        if bindings != ["NONE"]:
            for binding in bindings:
                key = calculator_key(binding)
                tests.append(f"kb_IsDown({key})")

        expression = " || ".join(tests) if tests else "false"

        source_lines += [
            "    {",
            f"        bool now = ({expression});",
            f"        _input_pressed[{index}] = now && !_input_down[{index}];",
            f"        _input_down[{index}] = now;",
            "    }",
        ]

    source_lines += [
        "}",
        "",
        "bool KeyDown(InputAction action) {",
        "    return action.id < INPUT_ACTION_COUNT && _input_down[action.id];",
        "}",
        "",
        "bool KeyJustPressed(InputAction action) {",
        "    return action.id < INPUT_ACTION_COUNT && _input_pressed[action.id];",
        "}",
        "",
    ]

    # === Write generated files ===

    os.makedirs(output_dir or ".", exist_ok=True)

    outputs = {
        os.path.join(output_dir, "input.h"): "\n".join(header_lines),
        os.path.join(output_dir, "input.c"): "\n".join(source_lines),
    }

    for path, content in outputs.items():
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
        else:
            with open(path, "r", encoding="utf-8") as f:
                old = f.read()

            if old != content:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)



# --------------------------------------------------
# Desktop / Keyboard backend
# --------------------------------------------------

def desktop_key(binding):
    if not binding.startswith("Key_"):
        fail(
            f"'{binding}' is not a desktop key. "
            "Expected a Key_ binding."
        )

    key = binding[4:]

    # Direct SDL scancode aliases
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
        f"Unknown desktop key '{binding}'. "
        "Add its SDL scancode mapping to desktop_key()."
    )


def generate_keyboard(definitions, blocks, output_dir):
    if "KEYBOARD" not in blocks:
        fail("Missing KEYBOARD block.")

    actions = blocks["KEYBOARD"]

    # === Generate input.h ===

    header_lines = [
        "// Generated by cbuild. Do not edit.",
        "#pragma once",
        "",
        "#include <stdint.h>",
        "#include <stdbool.h>",
        "",
        "typedef struct {",
        "    uint8_t id;",
        "    const char *name;",
        "} InputAction;",
        "",
        "typedef struct {",
    ]

    for action in definitions:
        header_lines.append(f"    InputAction {action};")

    header_lines += [
        "} InputBindings;",
        "",
        "extern const InputBindings INPUT;",
        "",
        f"#define INPUT_ACTION_COUNT {len(definitions)}",
        "",
        "void Input_Scan(void);",
        "bool KeyDown(InputAction action);",
        "bool KeyJustPressed(InputAction action);",
        "",
    ]

    # === Generate input.c ===

    source_lines = [
        "// Generated by cbuild. Do not edit.",
        "",
        '#include "input.h"',
        "#include <SDL.h>",
        '#include "keypadc.h"',
        "",
        "const InputBindings INPUT = {",
    ]

    for index, action in enumerate(definitions):
        data = actions[action]
        bindings = data["bindings"]

        name = data.get("name")

        if not name:
            name = (
                bindings[0].replace("Key_", "")
                if bindings[0] != "NONE"
                else action
            )

        source_lines.append(
            f"    .{action} = {{{index}, {c_string(name)}}},"
        )

    source_lines += [
        "};",
        "",
        "static bool _input_down[INPUT_ACTION_COUNT] = {0};",
        "static bool _input_pressed[INPUT_ACTION_COUNT] = {0};",
        "",
        "void Input_Scan(void) {",
        "    // Process SDL events through the desktop runtime.",
        "    kb_Scan();",
        "",
        "    const Uint8 *keyboard = SDL_GetKeyboardState(NULL);",
        "",
    ]

    for index, action in enumerate(definitions):
        bindings = actions[action]["bindings"]

        tests = []

        if bindings != ["NONE"]:
            for binding in bindings:
                key = desktop_key(binding)
                tests.append(f"keyboard[{key}]")

        expression = " || ".join(tests) if tests else "false"

        source_lines += [
            "    {",
            f"        bool now = ({expression});",
            f"        _input_pressed[{index}] = now && !_input_down[{index}];",
            f"        _input_down[{index}] = now;",
            "    }",
        ]

    source_lines += [
        "}",
        "",
        "bool KeyDown(InputAction action) {",
        "    return action.id < INPUT_ACTION_COUNT && _input_down[action.id];",
        "}",
        "",
        "bool KeyJustPressed(InputAction action) {",
        "    return action.id < INPUT_ACTION_COUNT && _input_pressed[action.id];",
        "}",
        "",
    ]

    # === Write generated files ===

    os.makedirs(output_dir or ".", exist_ok=True)

    outputs = {
        os.path.join(output_dir, "input.h"): "\n".join(header_lines),
        os.path.join(output_dir, "input.c"): "\n".join(source_lines),
    }

    for path, content in outputs.items():
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
        else:
            with open(path, "r", encoding="utf-8") as f:
                old = f.read()

            if old != content:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)


# --------------------------------------------------
# Main
# --------------------------------------------------

def main():
    if len(sys.argv) != 4:
        print(
            "Usage: generateinputs.py "
            "config.cfg output.h platform"
        )
        sys.exit(1)

    config = sys.argv[1]
    output = sys.argv[2]
    platform = sys.argv[3].lower()

    if platform not in PLATFORMS:
        fail(f"Unsupported platform '{platform}'.")

    definitions, blocks = parse_config(config)

    backend = PLATFORMS[platform]

    if "CALCULATOR" in backend:
        print("    - calculator")
        generate_calculator(definitions, blocks, output)

    elif "KEYBOARD" in backend:
        print("    - keyboard")
        generate_keyboard(definitions, blocks, output)

    # Need to make it be able to support multiple control skemes in the same platform

    else:
        print(
            f"[Warning] The {platform} input backend "
            "has not been implemented yet."
        )
        generate_placeholder(output)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        print(f"Input generation failed: {error}", file=sys.stderr)
        sys.exit(1)
