#!/usr/bin/env python3
"""Convert an equirectangular 360 panorama into the 3x2 cubemap atlas
used by interior_shader.gdshader (Godot 4 parallax interior).

Because all six faces are cut from one continuous panorama, every edge
matches by construction -- no seams.

Atlas layout (face size N, atlas 3N x 2N):
    top row:    +X wall   | +Y ceiling | +Z wall
    bottom row: -X wall   | -Y floor   | -Z wall

Room convention (must match the shader uniforms):
    x in [-W, 0]   (+X face at x=0  -> window side, -X far wall)
    z in [-L, 0]   (+Z face at z=-L, -Z face at z=0)
    y in [-H, 0]   (+Y ceiling at y=0, -Y floor at y=-H, H = 2*room_depth)

Faces are rendered as seen from the room center, with U flipped on -X
and -Z exactly as the shader does. In the panorama, the horizontal
center faces the -X direction (the far wall); the left/right edges
face +X (the window side).

Usage:
    python3 pano_to_atlas.py input_pano.jpg output_atlas.png \
        [--face-size 512] [--room 2.0 2.4 1.84]
"""

import argparse

import numpy as np
from PIL import Image


def face_points(name, u, v, W, L, H):
    """3D point on the given face for face-UVs (u, v) in [0, 1].

    v = 1 is the image top row. Mirrors sample_cubemap() including the
    shader's U flip on -X and -Z.
    """
    y = -H + H * v
    x = -W + W * u
    z = -L + L * v
    if name == "+X":
        return np.stack([np.zeros_like(u), y, -L + L * u], axis=-1)
    if name == "-X":  # U flipped: u=0 -> z=0
        return np.stack([-W * np.ones_like(u), y, -L * u], axis=-1)
    if name == "+Z":
        return np.stack([x, y, -L * np.ones_like(u)], axis=-1)
    if name == "-Z":  # U flipped: u=0 -> x=0
        return np.stack([-W * u, y, np.zeros_like(u)], axis=-1)
    if name == "+Y":
        return np.stack([x, np.zeros_like(u), z], axis=-1)
    if name == "-Y":
        return np.stack([x, -H * np.ones_like(u), z], axis=-1)
    raise ValueError(name)


def sample_equirect(pano, dirs):
    """Bilinear-sample an equirectangular image (H, W, C) at directions.

    Panorama center (u_eq = 0.5) looks along -X; u_eq = 0 along +X;
    v_eq = 0 is straight up. X wraps, Y clamps.
    """
    d = dirs / np.linalg.norm(dirs, axis=-1, keepdims=True)
    lon = np.arctan2(d[..., 2], d[..., 0])  # -x -> +pi, +x -> 0
    lat = np.arcsin(np.clip(d[..., 1], -1.0, 1.0))

    h, w = pano.shape[:2]
    ex = (lon / (2.0 * np.pi)) % 1.0 * w - 0.5
    ey = (0.5 - lat / np.pi) * h - 0.5

    x0 = np.floor(ex).astype(np.int64)
    y0 = np.floor(ey).astype(np.int64)
    fx = (ex - x0)[..., None]
    fy = (ey - y0)[..., None]

    x0w, x1w = x0 % w, (x0 + 1) % w
    y0c = np.clip(y0, 0, h - 1)
    y1c = np.clip(y0 + 1, 0, h - 1)

    c00 = pano[y0c, x0w].astype(np.float64)
    c10 = pano[y0c, x1w].astype(np.float64)
    c01 = pano[y1c, x0w].astype(np.float64)
    c11 = pano[y1c, x1w].astype(np.float64)

    top = c00 * (1.0 - fx) + c10 * fx
    bot = c01 * (1.0 - fx) + c11 * fx
    return (top * (1.0 - fy) + bot * fy).astype(pano.dtype)


LAYOUT = [  # (face name, grid column, grid row)
    ("+X", 0, 0), ("+Y", 1, 0), ("+Z", 2, 0),
    ("-X", 0, 1), ("-Y", 1, 1), ("-Z", 2, 1),
]


def convert(pano_path, out_path, n, room, rotate=0.0):
    W, L, H = room
    pano = np.asarray(Image.open(pano_path).convert("RGB"))

    # Rotate the panorama around the vertical axis so its horizontal
    # center faces the far wall (-X), as the shader expects.
    if rotate:
        shift = round(rotate / 360.0 * pano.shape[1])
        pano = np.roll(pano, shift, axis=1)

    cols, rows = np.meshgrid(np.arange(n), np.arange(n))
    u = cols / (n - 1.0)
    v = 1.0 - rows / (n - 1.0)  # image top row -> v = 1

    atlas = np.zeros((2 * n, 3 * n, 3), dtype=np.uint8)
    center = np.array([-W / 2.0, -H / 2.0, -L / 2.0])

    for name, cx, cy in LAYOUT:
        pts = face_points(name, u, v, W, L, H)
        face_img = sample_equirect(pano, pts - center)
        atlas[cy * n:(cy + 1) * n, cx * n:(cx + 1) * n] = face_img

    Image.fromarray(atlas).save(out_path)
    print(f"wrote {out_path} ({atlas.shape[1]}x{atlas.shape[0]})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", help="equirectangular panorama image")
    ap.add_argument("output", help="output atlas path (PNG recommended)")
    ap.add_argument("--face-size", type=int, default=512,
                    help="pixels per face (default: 512)")
    ap.add_argument("--room", type=float, nargs=3, default=[2.0, 2.0, 2.0],
                    metavar=("WIDTH", "LENGTH", "HEIGHT"),
                    help="room proportions matching the shader uniforms; "
                         "HEIGHT = 2 * room_depth (default: 2 2 2)")
    ap.add_argument("--rotate", type=float, default=0.0, metavar="DEGREES",
                    help="rotate the panorama around the vertical axis "
                         "(degrees, positive = content shifts right). Use "
                         "this if the far wall is not at the image center.")
    args = ap.parse_args()
    convert(args.input, args.output, args.face_size, args.room, args.rotate)
