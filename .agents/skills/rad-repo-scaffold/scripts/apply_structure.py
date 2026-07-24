#!/usr/bin/env python3
"""Preview or safely apply a repository structure from JSON."""
import argparse
import json
from pathlib import Path, PurePosixPath


def target(root: Path, raw: str) -> Path:
    rel = PurePosixPath(raw.replace("\\", "/"))
    if not raw or rel.is_absolute() or ".." in rel.parts:
        raise ValueError(f"unsafe path: {raw!r}")
    result = root.joinpath(*rel.parts).resolve()
    if result != root and root not in result.parents:
        raise ValueError(f"path escapes root: {raw!r}")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--plan", required=True, type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        parser.error("root must be an existing directory")
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    directories, files = plan.get("directories", []), plan.get("files", {})
    if not isinstance(directories, list) or not all(isinstance(x, str) for x in directories):
        raise ValueError("directories must be an array of strings")
    if not isinstance(files, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in files.items()):
        raise ValueError("files must map paths to string contents")
    conflicts = 0
    for raw in directories:
        path = target(root, raw)
        if path.is_dir():
            print(f"SKIP directory {raw}")
        elif path.exists():
            conflicts += 1; print(f"CONFLICT directory {raw}")
        else:
            print(f"CREATE directory {raw}")
            if args.apply: path.mkdir(parents=True)
    for raw, content in files.items():
        path = target(root, raw)
        if path.exists():
            conflicts += 1; print(f"CONFLICT file {raw}: refusing overwrite")
        else:
            print(f"CREATE file {raw}")
            if args.apply:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8", newline="\n")
    return 2 if conflicts else 0


if __name__ == "__main__":
    raise SystemExit(main())
