"""Build the ready-to-print, multi-plate Bambu Studio project for the camera.

The camera is cut at `chop_y` into a coloured FACE and a single-colour BODY, and the
rainbow stripe is printed separately and glued on. Each piece gets its own plate so
nothing needs cutting or arranging in the slicer:

  Plate 1  Face          black / cream / red / white, lens up
  Plate 2  Body          black only, cut face down
  Plate 3  Rainbow half  magenta / red / orange, standing on edge
  Plate 4  Rainbow half  yellow / green / blue, standing on edge

No plate uses more than four filaments, so every plate prints from one AMS.

Usage:  python3 build_plates.py [full|desk] [OUT.3mf]
Needs OpenSCAD (Manifold backend) plus the Python packages numpy and trimesh.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
import zipfile

import numpy as np
import trimesh

ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "print" / "bambu_project_settings_p2s_0.4.json"

VARIANTS = {
    # name: (OpenSCAD overrides, default output file)
    "full": (["-D", "squish=0", "-D", "top_slot=0", "-D", "scl=1"],
             "print/polaroid_full_size_4_plates.3mf"),
    "desk": (["-D", "squish=1", "-D", "top_slot=1", "-D", "scl=0.76"],
             "print/polaroid_desk_size_4_plates.3mf"),
}

# Project filament slots. Slot numbers are what each part is pinned to.
FILAMENTS = [
    ("black",   "#1C1C1C"),  # 1
    ("cream",   "#ECE8E0"),  # 2
    ("red",     "#CF2B2B"),  # 3  red button and the red rainbow stripe
    ("white",   "#FFFFFF"),  # 4  front lettering
    ("magenta", "#C63D96"),  # 5
    ("orange",  "#EE7D2A"),  # 6
    ("yellow",  "#F5C518"),  # 7
    ("green",   "#6F8F3E"),  # 8
    ("blue",    "#2F6FD0"),  # 9
]
SLOT = {name: i + 1 for i, (name, _) in enumerate(FILAMENTS)}
RAINBOW_ORDER = ["magenta", "red", "orange", "yellow", "green", "blue"]  # rb_band 0..5

BED = 256.0
PLATE_STRIDE = BED * 1.2  # Bambu Studio lays plates out on this grid


def find_openscad():
    exe = os.environ.get("OPENSCAD") or shutil.which("openscad")
    if not exe:
        candidate = Path("/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD")
        if candidate.is_file():
            exe = str(candidate)
    if not exe:
        sys.exit("Install OpenSCAD or set OPENSCAD to its executable path.")
    return exe


def render(exe, out, defines):
    cmd = [exe, "--backend=Manifold", "-D", "show_card=false", *defines,
           "-o", str(out), str(ROOT / "camera.scad")]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode or not out.is_file() or out.stat().st_size == 0:
        sys.exit(f"OpenSCAD failed for {out.name}:\n{done.stderr[-2000:]}")
    return out


def mesh_xml_from_3mf(path):
    """The <mesh> block exactly as OpenSCAD wrote it."""
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if name.endswith(".model"):
                xml = z.read(name).decode("utf-8", "ignore")
                if "<mesh" in xml:
                    return xml[xml.index("<mesh"):xml.index("</mesh>") + len("</mesh>")]
    sys.exit(f"no mesh in {path}")


def mesh_xml_from_trimesh(mesh):
    verts = "".join(f'<vertex x="{x:.5f}" y="{y:.5f}" z="{z:.5f}"/>' for x, y, z in mesh.vertices)
    tris = "".join(f'<triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in mesh.faces)
    return f"<mesh><vertices>{verts}</vertices><triangles>{tris}</triangles></mesh>"


def bounds_of(xml):
    v = np.array(re.findall(r'<vertex x="([-\d.eE+]+)" y="([-\d.eE+]+)" z="([-\d.eE+]+)"', xml), float)
    return v.min(axis=0), v.max(axis=0)


def rainbow_halves(exe, tmp, defines):
    """Stand the stripe on edge: the band-width direction becomes the print height.

    Each stripe is then a thin wall with no overhang, and colour changes happen once
    per 2 mm of height (two changes per half) instead of on every layer.
    """
    on_edge = np.array([[0, 1, 0, 0], [0, 0, 1, 0], [1, 0, 0, 0], [0, 0, 0, 1]], float)  # x->z, y->x, z->y
    bands = []
    for i in range(6):
        stl = render(exe, tmp / f"band{i}.stl", defines + ["-D", 'part="rainbow"', "-D", f"rb_band={i}"])
        mesh = trimesh.load(stl, force="mesh")
        mesh.apply_transform(on_edge)
        bands.append(mesh)
    halves = []
    for idx in ((0, 1, 2), (3, 4, 5)):
        group = [bands[i] for i in idx]
        floor = min(m.bounds[0][2] for m in group)
        for m in group:
            m.apply_translation([0, 0, -floor])
        halves.append([{"label": RAINBOW_ORDER[i], "slot": SLOT[RAINBOW_ORDER[i]],
                        "xml": mesh_xml_from_trimesh(bands[i])} for i in idx])
    return halves


def project_settings():
    """Bambu P2S / 0.4 mm / PLA settings, widened from the template to all filaments."""
    base = json.loads(TEMPLATE.read_text())
    old = len(base["filament_colour"])
    new = len(FILAMENTS)
    for key, val in list(base.items()):
        if not isinstance(val, list) or not val:
            continue
        if len(val) == old:                                # one value per filament
            base[key] = [val[i] if i < old else val[-1] for i in range(new)]
        elif len(val) == old * old:                        # filament-to-filament flush matrix
            grid = [[val[r * old + c] for c in range(old)] for r in range(old)]
            base[key] = [grid[r][c] if r < old and c < old else ("0" if r == c else "280")
                         for r in range(new) for c in range(new)]
        elif len(val) == 2 * old:                          # two nozzle variants per filament
            if key == "filament_self_index":
                base[key] = [str(i // 2 + 1) for i in range(2 * new)]
            else:
                base[key] = [val[(i // 2 % old) * 2 + i % 2] for i in range(2 * new)]
        elif len(val) == old + 2 and key in ("different_settings_to_system", "inherits_group"):
            base[key] = [val[0]] + [val[1]] * new + [val[-1]]   # process, each filament, printer
    colours = [hex_ for _, hex_ in FILAMENTS]
    base["filament_colour"] = colours
    if "filament_multi_colour" in base:
        base["filament_multi_colour"] = list(colours)
    base["enable_support"] = "0"
    return base


def write_project(out, plates):
    """plates: [{name, object_name, parts: [{label, slot, xml}]}], one object per plate."""
    core = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
    prod = "http://schemas.microsoft.com/3dmanufacturing/production/2015/06"
    bbl = "http://schemas.bambulab.com/package/2021"
    head = ('<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<model unit="millimeter" xml:lang="en-US" xmlns="{core}" xmlns:BambuStudio="{bbl}" '
            f'xmlns:p="{prod}" requiredextensions="p">\n'
            ' <metadata name="Application">BambuStudio-02.07.01.62</metadata>\n'
            ' <metadata name="BambuStudio:3mfVersion">1</metadata>\n')
    uid = lambda: str(uuid.uuid4())
    cols = int(np.ceil(np.sqrt(len(plates))))

    meshes, assemblies, items, settings, plate_xml = [], [], [], [], []
    mesh_id = 0
    for n, plate in enumerate(plates):
        asm = 100 + n
        ids = []
        lo = np.full(3, np.inf)
        hi = np.full(3, -np.inf)
        for part in plate["parts"]:
            mesh_id += 1
            ids.append(mesh_id)
            meshes.append(f'  <object id="{mesh_id}" p:UUID="{uid()}" type="model">{part["xml"]}</object>\n')
            a, b = bounds_of(part["xml"])
            lo, hi = np.minimum(lo, a), np.maximum(hi, b)
        if abs(lo[2]) > 0.02:
            sys.exit(f'{plate["name"]}: lowest point is at z={lo[2]:.3f}, not on the bed')
        if (hi[0] - lo[0]) > BED - 10 or (hi[1] - lo[1]) > BED - 10:
            sys.exit(f'{plate["name"]}: does not fit a {BED:g} mm bed')
        cx = (n % cols) * PLATE_STRIDE + BED / 2 - (lo[0] + hi[0]) / 2
        cy = -(n // cols) * PLATE_STRIDE + BED / 2 - (lo[1] + hi[1]) / 2
        comps = "".join(f'    <component p:path="/3D/Objects/object_1.model" objectid="{i}" p:UUID="{uid()}" '
                        'transform="1 0 0 0 1 0 0 0 1 0 0 0"/>\n' for i in ids)
        assemblies.append(f'  <object id="{asm}" p:UUID="{uid()}" type="model">\n   <components>\n{comps}'
                          '   </components>\n  </object>\n')
        items.append(f'  <item objectid="{asm}" p:UUID="{uid()}" '
                     f'transform="1 0 0 0 1 0 0 0 1 {cx:.4f} {cy:.4f} 0" printable="1"/>\n')
        settings.append(f'  <object id="{asm}">\n    <metadata key="name" value="{plate["object_name"]}"/>\n'
                        f'    <metadata key="extruder" value="{plate["parts"][0]["slot"]}"/>\n')
        for i, part in zip(ids, plate["parts"]):
            settings.append(f'    <part id="{i}" subtype="normal_part">\n'
                            f'      <metadata key="name" value="{part["label"]}"/>\n'
                            '      <metadata key="matrix" value="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1"/>\n'
                            f'      <metadata key="source_object_id" value="{i - 1}"/>\n'
                            '      <metadata key="source_volume_id" value="0"/>\n'
                            f'      <metadata key="extruder" value="{part["slot"]}"/>\n    </part>\n')
        settings.append("  </object>\n")
        plate_xml.append(f'  <plate>\n    <metadata key="plater_id" value="{n + 1}"/>\n'
                         f'    <metadata key="plater_name" value="{plate["name"]}"/>\n'
                         '    <metadata key="locked" value="false"/>\n'
                         f'    <model_instance>\n      <metadata key="object_id" value="{asm}"/>\n'
                         '      <metadata key="instance_id" value="0"/>\n    </model_instance>\n  </plate>\n')

    objects_model = head + " <resources>\n" + "".join(meshes) + " </resources>\n</model>\n"
    main_model = (head + " <resources>\n" + "".join(assemblies) + " </resources>\n"
                  f' <build p:UUID="{uid()}">\n' + "".join(items) + " </build>\n</model>\n")
    model_settings = ('<?xml version="1.0" encoding="UTF-8"?>\n<config>\n' + "".join(settings)
                      + "".join(plate_xml) + "</config>\n")
    content_types = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
                     ' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
                     ' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
                     ' <Default Extension="png" ContentType="image/png"/>\n</Types>\n')
    rel = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
           ' <Relationship Target="{}" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
           '</Relationships>\n')
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.writestr("[Content_Types].xml", content_types)
        z.writestr("_rels/.rels", rel.format("/3D/3dmodel.model"))
        z.writestr("3D/3dmodel.model", main_model)
        z.writestr("3D/_rels/3dmodel.model.rels", rel.format("/3D/Objects/object_1.model"))
        z.writestr("3D/Objects/object_1.model", objects_model)
        z.writestr("Metadata/model_settings.config", model_settings)
        z.writestr("Metadata/project_settings.config", json.dumps(project_settings(), indent=1))


def main():
    variant = sys.argv[1] if len(sys.argv) > 1 else "full"
    if variant not in VARIANTS:
        sys.exit(f"variant must be one of: {', '.join(VARIANTS)}")
    defines, default_out = VARIANTS[variant]
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / default_out
    exe = find_openscad()
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        face = []
        for colour in ("black", "cream", "red", "white"):
            f = render(exe, tmp / f"face_{colour}.3mf",
                       defines + ["-D", 'piece="face"', "-D", f'part="{colour}"'])
            face.append({"label": colour, "slot": SLOT[colour], "xml": mesh_xml_from_3mf(f)})
        body = render(exe, tmp / "body.3mf", defines + ["-D", 'piece="body"', "-D", 'part="all"'])
        half_a, half_b = rainbow_halves(exe, tmp, defines)
        write_project(out, [
            {"name": "1 Face - 4 colours", "object_name": "face", "parts": face},
            {"name": "2 Body - black", "object_name": "body",
             "parts": [{"label": "black", "slot": SLOT["black"], "xml": mesh_xml_from_3mf(body)}]},
            {"name": "3 Rainbow - magenta red orange", "object_name": "rainbow_left", "parts": half_a},
            {"name": "4 Rainbow - yellow green blue", "object_name": "rainbow_right", "parts": half_b},
        ])
    print(out)


if __name__ == "__main__":
    main()
