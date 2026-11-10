#!/usr/bin/env python3
"""Keep the published component JSON schema in sync with the runtime loader.

The schema is documentation *and* the contract served to AI authoring clients
through the component-authoring MCP server. A node or field the loader accepts
but the schema omits makes a valid component look invalid to those tools.

This check compares the loader's accepted node keys with the schema, then walks
every bundled component and public example to prove they conform.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOADER = ROOT / "Sources/RunningOverlay/Components/OverlayComponentLoader.swift"
SCHEMA = ROOT / "docs/overlay-components/schema/ros-component-0.1.schema.json"
SPEC = ROOT / "docs/overlay-components/spec-v0.1.md"
GUIDE = ROOT / "docs/overlay-components/authoring.md"
SKILL = ROOT / "docs/overlay-components/skills/overlay-component-authoring/SKILL.md"
COMPONENTS = sorted((ROOT / "Sources/RunningOverlay/Resources/Components").glob("*.json"))
EXAMPLES = sorted((ROOT / "docs/overlay-components/examples").glob("*.json"))

# The app serves these copies to AI authoring clients; they must match the docs.
SERVED_COPIES = {
    SCHEMA: ROOT / "Sources/RunningOverlay/Resources/Authoring/authoring-schema.json",
    SPEC: ROOT / "Sources/RunningOverlay/Resources/Authoring/authoring-spec.md",
    GUIDE: ROOT / "Sources/RunningOverlay/Resources/Authoring/authoring-guide.md",
    SKILL: ROOT / "Sources/RunningOverlay/Resources/Authoring/authoring-skill.md",
}

# Param controls share the `case "x": typeKeys = [...]` shape in the loader.
PARAM_TYPES = {"number", "bool", "color", "enum", "string", "font", "metric"}

# The loader still decodes this retired key so legacy weather components keep
# loading. It is deliberately absent from the authoring schema.
LEGACY_LOADER_KEYS = {("weatherWidget", "preset")}


def loader_surface() -> tuple[set[str], dict[str, set[str]]]:
    text = LOADER.read_text()
    common: set[str] | None = None
    for raw in re.findall(r"let commonKeys: Set<String> = \[(.*?)\]", text, re.S):
        keys = set(re.findall(r'"([^"]+)"', raw))
        if "alignSelf" in keys:
            common = keys
    if common is None:
        raise SystemExit("check-component-schema: cannot find node common keys in the loader")

    nodes: dict[str, set[str]] = {}
    for match in re.finditer(r'case "([A-Za-z]+)": typeKeys = \[(.*?)\]', text, re.S):
        name = match.group(1)
        if name in PARAM_TYPES:
            continue
        nodes[name] = set(re.findall(r'"([^"]+)"', match.group(2)))
    return common, nodes


def schema_surface() -> tuple[set[str], dict[str, set[str]], set[str]]:
    schema = json.loads(SCHEMA.read_text())
    defs = schema["$defs"]
    common = set(defs["nodeCommon"]["properties"])
    one_of = {ref["$ref"].rsplit("/", 1)[-1] for ref in defs["node"]["oneOf"]}

    nodes: dict[str, set[str]] = {}
    for name, definition in defs.items():
        if not name.endswith("Node") or name == "nodeCommon":
            continue
        props = set(common)
        for part in definition.get("allOf", []):
            props |= set(part.get("properties", {}))
        nodes[name[:-4]] = props
    return common, nodes, one_of


def walk(node: object, path: str, component: str, allowed: dict[str, set[str]], problems: list[str]) -> None:
    if not isinstance(node, dict):
        problems.append(f"{component}:{path}: node is not an object")
        return
    node_type = node.get("type")
    if node_type not in allowed:
        problems.append(f"{component}:{path}: unknown node type {node_type!r}")
        return
    extra = sorted(set(node) - allowed[node_type])
    if extra:
        problems.append(f"{component}:{path} ({node_type}): keys missing from schema: {extra}")
    for index, child in enumerate(node.get("children") or []):
        walk(child, f"{path}.children[{index}]", component, allowed, problems)


def main() -> int:
    common, loader_nodes = loader_surface()
    _, schema_nodes, schema_one_of = schema_surface()
    problems: list[str] = []

    for source, copy in SERVED_COPIES.items():
        if source.read_bytes() != copy.read_bytes():
            problems.append(
                f"{copy.relative_to(ROOT)} is out of sync with {source.relative_to(ROOT)}"
            )

    for node_type in sorted(loader_nodes):
        if node_type not in schema_nodes:
            problems.append(f"loader node {node_type!r} has no schema definition")
            continue
        if f"{node_type}Node" not in schema_one_of:
            problems.append(f"schema #/$defs/{node_type}Node is not referenced by node.oneOf")
        for key in sorted((loader_nodes[node_type] | common) - schema_nodes[node_type]):
            if (node_type, key) in LEGACY_LOADER_KEYS:
                continue
            problems.append(f"loader accepts {node_type}.{key}, schema does not")

    # The reverse direction is allowed: a stricter schema can retire a field,
    # but report it so the decision is visible.
    for node_type in sorted(set(schema_nodes) & set(loader_nodes)):
        for key in sorted(schema_nodes[node_type] - (loader_nodes[node_type] | common)):
            print(f"note: schema-only key {node_type}.{key} (loader does not read it)")

    for path in COMPONENTS + EXAMPLES:
        document = json.loads(path.read_text())
        for index, node in enumerate(document.get("nodes", [])):
            walk(node, f"nodes[{index}]", path.name, schema_nodes, problems)

    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1

    print(
        "Component schema check passed: "
        f"{len(loader_nodes)} node types, {len(COMPONENTS)} bundled components, "
        f"{len(EXAMPLES)} examples."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
