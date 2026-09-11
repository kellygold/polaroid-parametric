"""Export the standalone model without modifying its source."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("format", choices=("preview", "stl"))
args = parser.parse_args()
root = Path(__file__).resolve().parent
exe = os.environ.get("OPENSCAD") or shutil.which("openscad")
if not exe:
    candidate = Path("/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD")
    if candidate.is_file():
        exe = str(candidate)
if not exe:
    parser.error("Install OpenSCAD or set OPENSCAD to its executable path.")
out = root / "exports"
out.mkdir(exist_ok=True)
cmd = [exe, "--backend=Manifold", "-D", "show_card=false", "-D", "squish=0",
       "-D", "top_slot=0", "-D", "scl=1"]
if args.format == "preview":
    cmd += ["--preview", "--colorscheme=Tomorrow", "--imgsize=1400,1000",
            "--projection=o", "--camera=220,-340,210,0,0,45", "--viewall"]
    target = out / "camera.png"
else:
    target = out / "camera.stl"
subprocess.run(cmd + ["-o", str(target), str(root / "camera.scad")], check=True)
print(target)
