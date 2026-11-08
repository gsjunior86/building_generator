#!/usr/bin/env python3
"""Render a simple Brazilian apartment interior as an equirectangular
panorama, for testing the parallax interior atlas pipeline.

Room matches the shader test scene proportions:
    x in [-1.98, 0]  (window side at x=0, far wall at x=-1.98)
    z in [-2.4, 0]
    y in [-1.84, 0]  (floor to ceiling)
Camera at the room center. Output: equirectangular panorama where the
horizontal center faces -X (the far wall), as pano_to_atlas.py expects.
"""

import numpy as np
from PIL import Image

W_ROOM, L_ROOM, H_ROOM = 1.98, 2.4, 1.84
IMG_W, IMG_H = 2048, 1024

CENTER = np.array([-W_ROOM / 2, -H_ROOM / 2, -L_ROOM / 2])

rng = np.random.default_rng(7)


def hash1(n):
    return np.modf(np.sin(n * 127.1) * 43758.5453)[0]


def make_dirs():
    i = (np.arange(IMG_W) + 0.5) / IMG_W
    j = (np.arange(IMG_H) + 0.5) / IMG_H
    lon = i * 2.0 * np.pi  # i=0.5 (image center) -> lon=pi -> -X direction
    lat = (0.5 - j) * np.pi
    lon, lat = np.meshgrid(lon, lat)
    cl = np.cos(lat)
    return np.stack([cl * np.cos(lon), np.sin(lat), cl * np.sin(lon)], axis=-1)


# ----------------------------------------------------------------------
# scene
# ----------------------------------------------------------------------

def paint_room(p, n, albedo):
    """Base room surfaces (walls, floor, ceiling)."""
    x, y, z = p[..., 0], p[..., 1], p[..., 2]

    # walls: warm off-white
    wall = (np.abs(n[..., 0]) > 0.5) | (np.abs(n[..., 2]) > 0.5)
    albedo[wall] = (0.93, 0.91, 0.87)

    # accent far wall (-X): muted terracotta
    far = n[..., 0] > 0.5
    albedo[far] = (0.74, 0.47, 0.35)

    # window wall (+X): backlit sheer curtains with vertical folds
    curt = n[..., 0] < -0.5
    folds = 0.9 + 0.1 * np.sin(z[curt] * 28.0)
    albedo[curt] = np.stack([folds * 0.99, folds * 0.97, folds * 0.93], -1)

    # white skirting boards (rodape) along wall bottoms
    skirt = wall & (y < -H_ROOM + 0.07)
    albedo[skirt] = (0.96, 0.96, 0.95)

    # ceiling
    ceil = n[..., 1] < -0.5
    albedo[ceil] = (0.95, 0.95, 0.94)

    # floor: laminate oak planks running along z
    floor_m = n[..., 1] > 0.5
    if np.any(floor_m):
        fx, fz = x[floor_m], z[floor_m]
        plank = np.floor((fx + W_ROOM) / 0.18)
        shade = 0.82 + 0.3 * hash1(plank)
        grain = 0.04 * np.sin(fz * 45.0 + hash1(plank) * 20.0)
        seam = (np.modf((fx + W_ROOM) / 0.18)[0] < 0.05) * 0.25
        base = np.stack([0.66, 0.5, 0.34], -1) * (shade + grain - seam)[..., None]
        albedo[floor_m] = base

        # rug
        rug = (floor_m & (x > -1.75) & (x < -0.65) &
               (z > -1.95) & (z < -0.55))
        border = ((x < -1.68) | (x > -0.72) |
                  (z < -1.88) | (z > -0.62))
        col = np.where(border[..., None], np.array([0.62, 0.36, 0.24]),
                       np.array([0.86, 0.83, 0.76]))
        albedo[rug] = col[rug]


BOXES = []  # (mins, maxs, painter)


def box(mins, maxs, painter):
    BOXES.append((np.array(mins), np.array(maxs), painter))


def solid(color):
    return lambda p, n, m: np.tile(np.array(color), (m.sum(), 1))


# sofa (base + backrest) against the far wall
box([-1.95, -1.84, -2.05], [-1.45, -1.35, -0.35], solid((0.6, 0.61, 0.63)))
box([-1.95, -1.35, -2.05], [-1.68, -0.82, -0.35], solid((0.55, 0.56, 0.58)))
# cushions: orange + olive green
box([-1.66, -1.32, -1.95], [-1.48, -0.95, -1.45], solid((0.85, 0.5, 0.24)))
box([-1.66, -1.32, -1.0], [-1.48, -0.95, -0.55], solid((0.42, 0.55, 0.38)))

# TV wood panel + black screen on the far wall
box([-1.98, -1.55, -1.9], [-1.94, -0.15, -0.5], solid((0.45, 0.3, 0.18)))
box([-1.94, -1.25, -1.6], [-1.9, -0.55, -0.8], solid((0.05, 0.05, 0.07)))
# white rack under the TV
box([-1.98, -1.84, -1.85], [-1.58, -1.6, -0.55], solid((0.88, 0.86, 0.82)))


# bookshelf on the +Z wall, books painted on its room-facing side
def paint_shelf(p, n, m):
    cols = np.tile(np.array([0.32, 0.22, 0.13]), (m.sum(), 1))
    face = n[m, 2] > 0.5
    if np.any(face):
        px, py = p[m, 0][face], p[m, 1][face]
        shelf = np.floor((py + 1.84) / 0.33)
        spine = np.floor((px + 1.5) / 0.045)
        h = hash1(shelf * 57.0 + spine)
        inside = ((py + 1.84) % 0.33 < 0.27)
        hue = np.stack([0.4 + 0.5 * h, 0.3 + 0.4 * hash1(spine),
                        0.35 + 0.4 * hash1(spine * 3.7)], -1)
        cols[face] = np.where(inside[..., None], hue, cols[face])
    return cols


box([-1.5, -1.84, -2.4], [-0.5, -0.45, -2.12], paint_shelf)

# door + frame on the -Z wall
box([-1.66, -1.84, -0.04], [-0.84, -0.28, 0.0], solid((0.9, 0.89, 0.87)))
box([-1.6, -1.84, -0.06], [-0.9, -0.34, -0.02], solid((0.42, 0.28, 0.16)))
# framed picture next to the door
box([-0.75, -1.35, -0.04], [-0.15, -0.55, 0.0], solid((0.2, 0.18, 0.16)))
box([-0.69, -1.29, -0.06], [-0.21, -0.61, -0.03], solid((0.55, 0.65, 0.72)))

# coffee table on the rug
box([-1.35, -1.84, -1.55], [-0.85, -1.52, -0.85], solid((0.35, 0.24, 0.15)))
# plant: terracotta pot
box([-0.55, -1.84, -2.35], [-0.2, -1.52, -2.0], solid((0.62, 0.33, 0.2)))

SPHERE = (np.array([-0.375, -1.0, -2.175]), 0.36, (0.24, 0.44, 0.22))


# ----------------------------------------------------------------------
# ray tracing
# ----------------------------------------------------------------------

def render():
    d = make_dirs()
    shape = d.shape[:2]

    best_t = np.full(shape, np.inf)
    normal = np.zeros((*shape, 3))
    albedo = np.zeros((*shape, 3))

    # room box planes (ray starts inside, nearest positive t wins)
    planes = [
        (-W_ROOM, 0, np.array([1.0, 0, 0])),
        (0.0, 0, np.array([-1.0, 0, 0])),
        (-H_ROOM, 1, np.array([0, 1.0, 0])),
        (0.0, 1, np.array([0, -1.0, 0])),
        (-L_ROOM, 2, np.array([0, 0, 1.0])),
        (0.0, 2, np.array([0, 0, -1.0])),
    ]
    for offset, axis, nrm in planes:
        t = (offset - CENTER[axis]) / d[..., axis]
        hit = (t > 1e-6) & (t < best_t)
        best_t[hit] = t[hit]
        normal[hit] = nrm

    point = CENTER + best_t[..., None] * d
    paint_room(point, normal, albedo)

    # furniture boxes (slab test)
    for mins, maxs, painter in BOXES:
        inv = 1.0 / d
        t0 = (mins - CENTER) * inv
        t1 = (maxs - CENTER) * inv
        tmin = np.minimum(t0, t1)
        tmax = np.maximum(t0, t1)
        tn = tmin.max(axis=-1)
        tf = tmin.max(axis=-1) * 0 + tmax.min(axis=-1)
        hit = (tf > tn) & (tn > 1e-6) & (tn < best_t)
        if not np.any(hit):
            continue
        best_t[hit] = tn[hit]
        axis = tmin.argmax(axis=-1)
        n = np.zeros((*shape, 3))
        for a in range(3):
            sel = hit & (axis == a)
            n[sel, a] = -np.sign(d[sel, a])
        normal[hit] = n[hit]
        point = CENTER + best_t[..., None] * d
        albedo[hit] = painter(point, normal, hit)

    # plant foliage sphere
    c_s, r_s, col_s = SPHERE
    oc = CENTER - c_s
    b = (oc * d).sum(-1)
    c_q = (oc * oc).sum() - r_s * r_s
    disc = b * b - c_q
    t_s = -b - np.sqrt(np.maximum(disc, 0))
    hit = (disc > 0) & (t_s > 1e-6) & (t_s < best_t)
    best_t[hit] = t_s[hit]
    point = CENTER + best_t[..., None] * d
    sn = (point[hit] - c_s) / r_s
    normal[hit] = sn
    var = 0.8 + 0.4 * hash1(np.floor(sn[:, 0] * 9) + np.floor(sn[:, 1] * 9) * 3)
    albedo[hit] = np.array(col_s) * var[:, None]

    # ------------------------------------------------------------------
    # lighting
    # ------------------------------------------------------------------
    light_dir = np.array([0.8, 0.4, 0.2])
    light_dir /= np.linalg.norm(light_dir)
    lamp_pos = np.array([CENTER[0], -0.06, CENTER[2]])

    diff = np.maximum((normal * light_dir).sum(-1), 0.0) * 0.45
    to_lamp = lamp_pos - point
    dist2 = np.maximum((to_lamp * to_lamp).sum(-1), 1e-4)
    tl = to_lamp / np.sqrt(dist2)[..., None]
    lamp = np.maximum((normal * tl).sum(-1), 0.0) * 0.5 / (1.0 + 0.8 * dist2)

    shade = 0.62 + diff + lamp
    img = albedo * shade[..., None]

    # ceiling lamp (emissive, painted over ceiling)
    ceil_m = normal[..., 1] < -0.5
    dxz2 = (point[..., 0] - CENTER[0]) ** 2 + (point[..., 2] - CENTER[2]) ** 2
    lamp_disc = ceil_m & (dxz2 < 0.045)
    glow = ceil_m & ~lamp_disc & (dxz2 < 0.25)
    img[lamp_disc] = (1.0, 0.93, 0.78)
    img[glow] = np.minimum(img[glow] + 0.25, 1.0)

    return np.clip(img, 0.0, 1.0) ** (1.0 / 1.8)


img = (render() * 255).astype(np.uint8)
Image.fromarray(img).save("/tmp/apartment_pano.png")
print("wrote /tmp/apartment_pano.png")
