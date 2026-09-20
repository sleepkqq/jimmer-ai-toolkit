#!/usr/bin/env python3
"""Check portable skill metadata, local links, version-free guidance and fixtures."""

import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
errors = []
skills = sorted((ROOT / "skills").glob("*/SKILL.md"))
names = {path.parent.name for path in skills}
for path in skills:
    text = path.read_text()
    match = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not match:
        errors.append(f"{path.relative_to(ROOT)}: missing frontmatter")
        continue
    fields = dict(re.findall(r"^([a-z-]+): (.+)$", match[1], re.M))
    if fields.get("name") != path.parent.name:
        errors.append(f"{path}: name does not match directory")
    description = fields.get("description", "")
    if not 1 <= len(description) <= 1024 or ": " in description:
        errors.append(f"{path}: invalid unquoted description")
    if len(text.splitlines()) > 500:
        errors.append(f"{path}: entry point exceeds 500 lines")

for path in sorted((ROOT / "skills").rglob("*.md")):
    text = path.read_text()
    if re.search(r"\b[vV]?\d+\.\d+(?:\.\d+|\.[xX])?\b", text):
        errors.append(f"{path}: fixed library version in skill guidance")
    for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
        if "://" in target or target.startswith("#"):
            continue
        if not (path.parent / target.split("#")[0]).exists():
            errors.append(f"{path}: broken local link {target}")
    for name in re.findall(r"`(jimmer-[a-z-]+)`", text):
        if name in {"jimmer-apt", "jimmer-ksp", "jimmer-ddl-compiler",
                    "jimmer-spring-boot-starter", "jimmer-bom", "jimmer-sql", "jimmer-sql-kotlin"}:
            continue
        if name not in names:
            errors.append(f"{path}: unknown sibling skill {name}")

case_count = 0
for suite in sorted((ROOT / "tests/skill-evals").glob("*cases.json")):
    cases = json.loads(suite.read_text())["cases"]
    assert len({case["id"] for case in cases}) == len(cases), f"duplicate canary IDs in {suite}"
    for case in cases:
        assert case["prompt"] and case["assertions"], f"empty case {case['id']}"
        assert set(case["skills"]) <= names, f"unknown skill in {case['id']}"
    case_count += len(cases)

scripts = sorted((ROOT / "skills").rglob("*.sh"))
for path in scripts:
    result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
    if result.returncode:
        errors.append(f"{path}: {result.stderr.strip()}")

if errors:
    raise SystemExit("\n".join(errors))
print(f"Validated {len(skills)} skills, local references, {case_count} canaries and {len(scripts)} shell helpers")
