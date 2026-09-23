#!/usr/bin/env python3
"""
fix_patch_types.py

Corrige el "type" de patches específicos en un archivo constant/polyMesh/boundary
de OpenFOAM, editando el texto directamente.

Por qué no usamos foamDictionary: el archivo boundary es técnicamente una
lista anónima de entradas (aparece como "entry0" para foamDictionary), no un
diccionario navegable por nombre de patch -- foamDictionary no puede hacer
"-entry front.type" ahí. Editar el texto es más simple y confiable para este
caso puntual.

Uso:
    python fix_patch_types.py <archivo_boundary> front:empty back:empty airfoil:wall
"""

import re
import sys


def fix_patch_type(text, patch_name, new_type):
    # Busca el bloque "nombre { ... }" (sin llaves anidadas dentro, que es
    # como son los bloques de patch en este archivo) y dentro de ese bloque
    # reemplaza la línea "type ...;" por el nuevo tipo.
    pattern = re.compile(
        r"(\b" + re.escape(patch_name) + r"\s*\{[^{}]*?type\s+)\w+(\s*;)",
        re.DOTALL,
    )
    new_text, n = pattern.subn(rf"\g<1>{new_type}\g<2>", text, count=1)
    if n == 0:
        raise ValueError(f"No encontré el patch '{patch_name}' en el archivo (¿nombre correcto?)")
    return new_text


def main():
    if len(sys.argv) < 3:
        print("Uso: python fix_patch_types.py <archivo_boundary> patch:tipo [patch:tipo ...]")
        sys.exit(1)

    path = sys.argv[1]
    changes = sys.argv[2:]

    with open(path) as f:
        text = f.read()

    for change in changes:
        patch_name, new_type = change.split(":")
        text = fix_patch_type(text, patch_name, new_type)
        print(f"  {patch_name} -> type {new_type}")

    with open(path, "w") as f:
        f.write(text)

    print(f"Escrito: {path}")


if __name__ == "__main__":
    main()
