#!/usr/bin/env python3
"""Build a portable Windows installer ZIP. Never includes host certificates or secrets."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parents[1] / 'assets' / 'windows'
args.output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(args.output, 'w', ZIP_DEFLATED) as archive:
    for file in sorted(source.iterdir()):
        if file.is_file() and file.suffix in {'.ps1', '.cjs'}:
            archive.write(file, 'chatgpt-desktop-local-repair/' + file.name)
print(args.output.resolve())
