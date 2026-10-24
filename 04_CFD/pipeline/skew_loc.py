import re, sys, os
case = sys.argv[1] if len(sys.argv) > 1 else "."
setname = sys.argv[2] if len(sys.argv) > 2 else "skewFaces"
pm = os.path.join(case, "constant", "polyMesh")

def body(path):
    t = open(path, errors="ignore").read()
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    t = re.sub(r"//[^\n]*", "", t)
    t = re.sub(r"FoamFile\s*\{.*?\}", "", t, flags=re.S)
    return t

pts = [tuple(map(float, m)) for m in re.findall(
    r"\(\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)\s*\)", body(os.path.join(pm, "points")))]
faces = [list(map(int, m.split())) for m in re.findall(
    r"\d+\s*\(([\d\s]+)\)", body(os.path.join(pm, "faces")))]
labels = [int(x) for x in re.findall(r"\d+", body(os.path.join(pm, "sets", setname)))[1:]]

print(f"{len(pts)} puntos, {len(faces)} caras, {len(labels)} caras en el set '{setname}'")
print("cara   x_centro   y_centro   z_centro")
for lab in labels:
    f = faces[lab]
    cx = sum(pts[i][0] for i in f) / len(f)
    cy = sum(pts[i][1] for i in f) / len(f)
    cz = sum(pts[i][2] for i in f) / len(f)
    print(f"{lab:6d} {cx:10.5f} {cy:10.5f} {cz:10.5f}")
