#!/usr/bin/env python3
"""Inyecta las fotos de la carpeta `media` dentro de index.html (todo en un solo archivo).

Cada foto debe llamarse igual que el producto (sin importar mayúsculas, tildes ni la
extensión). Ejemplo: "Blusa perla.jpg" -> producto "Blusa Perla".

Uso:
    python inyectar_imagenes.py                      # busca la carpeta media sola
    python inyectar_imagenes.py --media "C:/ruta/Documentos/media"
    python inyectar_imagenes.py --probar             # solo muestra qué haría, no escribe

Requiere Python 3 y Pillow (pip install pillow). Se puede ejecutar las veces que quieras:
cada vez reemplaza por completo las imágenes anteriores del HTML.
"""
import argparse
import base64
import io
import json
import re
import sys
import unicodedata
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.exit("Falta Pillow. Instálalo con:  pip install pillow")

EXTENSIONES = {".jpg", ".jpeg", ".png", ".webp"}
LADO_MAX = (1000, 1250)  # ancho y alto máximos en píxeles
CALIDAD = 80
BLOQUE_IMAGENES = re.compile(
    r'(<script id="imagenes-data" type="application/json">)(.*?)(</script>)', re.DOTALL
)
BLOQUE_CATALOGO = re.compile(
    r'<script id="catalogo-data" type="application/json">(.*?)</script>', re.DOTALL
)


def normalizar(texto):
    texto = unicodedata.normalize("NFD", texto)
    texto = "".join(c for c in texto if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", texto.casefold()).strip()


def buscar_media(indicada, carpeta_script):
    if indicada:
        ruta = Path(indicada).expanduser()
        return ruta if ruta.is_dir() else None
    home = Path.home()
    candidatas = [carpeta_script / "media", Path.cwd() / "media"]
    for base in ("Documents", "Documentos"):
        candidatas.append(home / base / "media")
    for patron in ("OneDrive*/Documents/media", "OneDrive*/Documentos/media"):
        candidatas.extend(sorted(home.glob(patron)))
    for c in candidatas:
        if c.is_dir():
            return c
    return None


def emparejar(productos, archivos):
    """Devuelve ({id: Path}, [productos sin foto], [fotos sin producto])."""
    por_nombre = {}
    for f in archivos:
        por_nombre.setdefault(normalizar(f.stem), []).append(f)
    usados, asignadas, sin_foto = set(), {}, []
    for p in productos:
        clave = normalizar(p["archivo"])
        candidatos = por_nombre.get(clave)
        if not candidatos:
            # nombres cortados: acepta solo si el prefijo identifica un único producto
            prefijos = [k for k in por_nombre if clave.startswith(k) or k.startswith(clave)]
            candidatos = por_nombre[prefijos[0]] if len(prefijos) == 1 else None
        if candidatos:
            asignadas[p["id"]] = candidatos[0]
            usados.add(candidatos[0])
        else:
            sin_foto.append(p)
    sobrantes = [f for f in archivos if f not in usados]
    return asignadas, sin_foto, sobrantes


def a_data_uri(ruta):
    with Image.open(ruta) as im:
        im = ImageOps.exif_transpose(im)
        if im.mode not in ("RGB", "L"):
            fondo = Image.new("RGB", im.size, (14, 7, 9))
            fondo.paste(im.convert("RGBA"), mask=im.convert("RGBA").split()[-1])
            im = fondo
        else:
            im = im.convert("RGB")
        im.thumbnail(LADO_MAX, Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "WEBP", quality=CALIDAD, method=6)
    return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode("ascii"), len(buf.getvalue())


def main():
    aqui = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description="Inyecta las fotos de media/ en index.html")
    ap.add_argument("--media", help="carpeta con las fotos (por defecto la busca sola)")
    ap.add_argument("--html", default=str(aqui / "index.html"), help="archivo HTML a actualizar")
    ap.add_argument("--probar", action="store_true", help="solo reporta, no escribe nada")
    args = ap.parse_args()

    html_path = Path(args.html)
    if not html_path.is_file():
        sys.exit("No encuentro el HTML: %s" % html_path)
    media = buscar_media(args.media, aqui)
    if media is None:
        sys.exit("No encuentro la carpeta media. Indícala con:  --media \"RUTA\"")

    html = html_path.read_text(encoding="utf-8")
    m = BLOQUE_CATALOGO.search(html)
    if not m or not BLOQUE_IMAGENES.search(html):
        sys.exit("El HTML no tiene los bloques catalogo-data / imagenes-data.")
    productos = json.loads(m.group(1))

    archivos = sorted(p for p in media.iterdir() if p.is_file() and p.suffix.lower() in EXTENSIONES)
    asignadas, sin_foto, sobrantes = emparejar(productos, archivos)

    print("Carpeta: %s  (%d fotos)" % (media, len(archivos)))
    imagenes, total_antes, total_despues = {}, 0, 0
    for p in productos:
        ruta = asignadas.get(p["id"])
        if not ruta:
            continue
        try:
            uri, peso = a_data_uri(ruta)
        except Exception as err:  # foto dañada o formato raro
            print("  [ERROR] %s: %s" % (ruta.name, err))
            sin_foto.append(p)
            continue
        imagenes[p["id"]] = uri
        total_antes += ruta.stat().st_size
        total_despues += peso
        print("  [ok] %-26s <- %-34s %4d KB -> %4d KB" % (p["nombre"], ruta.name, ruta.stat().st_size // 1024, peso // 1024))

    print("\nProductos con foto: %d de %d" % (len(imagenes), len(productos)))
    for p in sin_foto:
        print("  [falta foto] %s  (se esperaba: \"%s\")" % (p["nombre"], p["archivo"]))
    for f in sobrantes:
        print("  [sin producto] %s  (no coincide con ningún nombre)" % f.name)

    if args.probar:
        print("\n--probar: no se escribió nada.")
        return
    if not imagenes:
        sys.exit("\nNo se inyectó nada: ninguna foto coincide con un producto.")

    json_imgs = json.dumps(imagenes, separators=(",", ":"))
    nuevo = BLOQUE_IMAGENES.sub(lambda mo: mo.group(1) + json_imgs + mo.group(3), html, count=1)
    html_path.write_text(nuevo, encoding="utf-8")
    peso_html = html_path.stat().st_size / (1024 * 1024)
    print("\nFotos: %d KB -> %d KB (WebP)." % (total_antes // 1024, total_despues // 1024))
    print("Actualizado %s (%.1f MB)." % (html_path.name, peso_html))
    if peso_html > 8:
        print("Aviso: el archivo pesa más de 8 MB; baja LADO_MAX o CALIDAD en el script.")


if __name__ == "__main__":
    main()
