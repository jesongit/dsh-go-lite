#!/usr/bin/env python3
"""Windows-capable equivalent of build-apk.sh; preserves flavor and versionCode contracts.

python tooling/build_apk.py --build-name 1.2.3 -f all --dry-run
Extra Flutter flags follow --. Builds use the installed Flutter/Android toolchain.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

from build_number import build_number, check, decode
from release_assets import apk_version, find_aapt2

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
PLATFORMS = {"arm64": "android-arm64", "x64": "android-x64"}


def arguments(argv: list[str]):
    split = argv.index("--") if "--" in argv else len(argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-f", "--flavor", choices=["arm64", "x64", "all"], default="arm64")
    mode = parser.add_mutually_exclusive_group()
    for name in ("release", "debug", "profile"):
        mode.add_argument(f"--{name}", dest="mode", action="store_const", const=name)
    parser.set_defaults(mode="release")
    parser.add_argument("-t", "--target")
    parser.add_argument("-n", "--build-number", type=int)
    parser.add_argument("--build-name")
    parser.add_argument("--keep-daemon", action="store_true")
    parser.add_argument("--beta", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv[:split])
    extra = argv[split + 1:]
    for arg in extra:
        if arg.startswith(("--build-number", "--build-name", "--flavor", "--target-platform", "--split-per-abi")):
            parser.error(f"{arg} is controlled by this script; use its own options")
    args.extra = extra
    return args


def commands(args, name: str, code: int, beta_json: Path | None = None):
    flavors = list(PLATFORMS) if args.flavor == "all" else [args.flavor]
    for flavor in flavors:
        cmd = ["flutter", "build", "apk", f"--{args.mode}", "--flavor", flavor,
               "--target-platform", PLATFORMS[flavor], "--build-name", name,
               "--build-number", str(code), f"--dart-define=DSH_APP_VERSION={name}+{code}"]
        if args.target:
            cmd += ["-t", args.target]
        if beta_json:
            cmd += [f"--dart-define-from-file={beta_json}"]
        yield flavor, cmd + args.extra


def main(argv=None):
    args = arguments(sys.argv[1:] if argv is None else argv)
    name = args.build_name
    if not name:
        match = re.search(r"^version:\s*([^+\s]+)", (APP / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
        if not match:
            raise ValueError("version not found in app/pubspec.yaml")
        name = match.group(1)
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", name):
        raise ValueError(f"not a version name: {name!r}")
    code = args.build_number if args.build_number is not None else build_number()
    check(code)
    try:
        when = f"{decode(code):%Y-%m-%d %H:%M} UTC+8"
    except ValueError:
        when = "custom"
    beta_file = Path(os.environ.get("DSH_BETA_TOKEN_FILE", str(Path.home() / "keys/dshgo-beta-channel.token")))
    if args.beta and (not beta_file.is_file() or not beta_file.stat().st_size):
        raise ValueError("--beta needs a nonempty beta channel token file")
    beta = args.beta and args.mode == "release"
    if beta and os.name != "nt" and stat.S_IMODE(beta_file.stat().st_mode) not in (0o600, 0o400):
        raise ValueError("beta channel token file must have mode 600 or 400")
    print(f"dsh-go {name} ({code}, {when}) · {args.mode} · {args.flavor}", flush=True)
    preview = list(commands(args, name, code, APP / "build/.beta-channel.json" if beta else None))
    if args.dry_run:
        for _, cmd in preview:
            print(f"(cd app && {subprocess.list2cmdline(cmd)})")
        if not args.keep_daemon:
            print("(cd app/android && gradlew --stop)")
        return
    flutter = shutil.which("flutter.bat" if os.name == "nt" else "flutter")
    if not flutter:
        raise ValueError("flutter is not on PATH")
    aapt2 = find_aapt2()
    if not aapt2:
        print("build-apk: aapt2 not found; APK version cannot be read back", file=sys.stderr)
    beta_json = None
    built = []
    try:
        if beta:
            (APP / "build").mkdir(exist_ok=True)
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix=".beta-channel-", suffix=".json", dir=APP / "build", delete=False) as stream:
                beta_json = Path(stream.name)
                json.dump({"DSH_BETA_CHANNEL_TOKEN": beta_file.read_text(encoding="utf-8").strip()}, stream)
        for flavor, cmd in commands(args, name, code, beta_json):
            cmd[0] = flutter
            subprocess.run(cmd, cwd=APP, check=True)
            apk = APP / f"build/app/outputs/flutter-apk/app-{flavor}-{args.mode}.apk"
            if not apk.is_file():
                raise ValueError(f"{flavor}: no APK at {apk}")
            if aapt2 and apk_version(aapt2, apk) != (name, code):
                raise ValueError(f"{flavor}: APK version differs from {name}+{code}")
            built.append(apk)
    finally:
        if beta_json:
            beta_json.unlink(missing_ok=True)
        wrapper = APP / ("android/gradlew.bat" if os.name == "nt" else "android/gradlew")
        if not args.keep_daemon and wrapper.is_file():
            subprocess.run([str(wrapper), "--stop", "-q"], cwd=wrapper.parent, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for apk in built:
        print(apk.relative_to(ROOT))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"build-apk: {error}")
