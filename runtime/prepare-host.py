#!/usr/bin/env python3
"""Prepare a disposable, pinned DSH host for bridge and patch tests.

python runtime/prepare-host.py --out /absolute/empty/test-directory
The output is host test tooling; nothing is bundled into the mobile client.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent


def prepare(out: Path) -> dict[str, str]:
    versions = json.loads((HERE / "host-versions.json").read_text(encoding="utf-8"))
    # Refuse an existing tree rather than deleting or mixing unknown data with fixtures.
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f"host fixture directory must be empty: {out}")
    out.mkdir(parents=True, exist_ok=True)
    npm = shutil.which("npm.cmd" if os.name == "nt" else "npm")
    if not npm:
        raise SystemExit("npm is required")
    prefixes = {}
    for kind in ("dsh", "pnpm"):
        prefix = out / kind
        prefix.mkdir()
        lock = HERE / "locks" / f"{kind}-{versions[kind]}"
        for name in ("package.json", "package-lock.json"):
            shutil.copyfile(lock / name, prefix / name)
        subprocess.run([npm, "ci", "--prefix", str(prefix), "--ignore-scripts", "--no-audit", "--no-fund"], check=True)
        prefixes[kind] = prefix
    prefix = prefixes["dsh"]
    original = prefix / "fs-local-original.js"
    shutil.copyfile(prefix / "node_modules/@deepseek-ai/dsh-fs-local/lib/index.js", original)
    subprocess.run([sys.executable, "-I", str(HERE / "lib/patch_dsh.py"), "patch-dsh", "--prefix", str(prefix), "--dsh-version", versions["dsh"]], check=True)
    values = {
        "DSH_PREFIX": str(prefix),
        "DSH_TEST_PREFIX": str(prefix),
        "PNPM_BIN": str(prefixes["pnpm"] / "node_modules/pnpm/bin/pnpm.mjs"),
        "DSH_INSTALL": str(prefix / "node_modules/@deepseek-ai/dsh"),
        "DSH_TOOLS_DIR": str(prefix / "node_modules/@deepseek-ai/dsh-tools"),
        "DSH_FS_LOCAL_ORIGINAL_JS": str(original),
    }
    (out / "host-env.json").write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--github-env", type=Path, help="append fixture paths to the CI environment file")
    args = parser.parse_args()
    values = prepare(args.out.resolve())
    if args.github_env:
        with args.github_env.open("a", encoding="utf-8") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
    print(f"Host fixture ready; environment paths: {args.out.resolve() / 'host-env.json'}")


if __name__ == "__main__":
    main()
