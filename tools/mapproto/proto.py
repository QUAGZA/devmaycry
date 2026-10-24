#!/usr/bin/env python
"""ECHO CLASH map prototyping toolkit (offline, fast).

Author a map as a STREET NETWORK: free rectangles (streets, plazas, courts), enterable rooms, raised
platforms, sunken floors. Everything inside the outline that is not free becomes solid building masses
(solidify). The same plan is then
  * analysed: sightline statistics, visibility from spawns/objectives, carry-route lengths per layer,
  * drawn: plan image with sight heat map and routes,
  * exported: src/maps/plans/<name>_plan.gd, a flat op list executed by PlanRunner.gd in the game.

Run with plain `python` (needs numpy + Pillow from the user site-packages, not `python -I`).
Conventions: plan coordinates (x, z) in metres, z grows to the south (down in the image), y is up.
Yaw follows Godot (rotation about +Y): local +x axis = (cos t, -sin t), local +z axis = (sin t, cos t).
"""
import copy
import heapq
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

RES = 0.5            # raster cell (m)
AGENT_R = 0.75       # navmesh agent radius 0.6 plus cell-size erosion: passages under ~1.5 m close in the engine
EYE = 1.6
STEP_H = 0.55
CLEAR_H = 2.0


def r1(v):
    return round(float(v), 2)


# ---------------------------------------------------------------- mirroring (x -> -x)
def _mx(p):
    return [r1(-p[0])] + [r1(c) for c in p[1:]]


def mirror_op(op):
    o = copy.deepcopy(op)
    t = op["op"]
    if t in ("free", "block", "room", "sunken", "wall_rect"):
        x0, z0, x1, z1 = op["r"]
        o["r"] = [r1(-x1), z0, r1(-x0), z1]
        if t == "room":
            d = op.get("doors", {})
            nd = {}
            for side, lst in d.items():
                if side in ("n", "s"):
                    nd[side] = [[r1(-off), w] for off, w in lst]
                else:
                    nd["e" if side == "w" else "w"] = [list(x) for x in lst]
            o["doors"] = nd
            for k in ("lights",):
                if k in o:
                    o[k] = [_mx(p) for p in o[k]]
    elif t in ("free_poly", "slab", "poly_block"):
        o["poly"] = [[r1(-p[0]), p[1]] for p in reversed(op["poly"])]
    elif t == "wall":
        o["a"] = _mx(op["a"])
        o["b"] = _mx(op["b"])
    elif t in ("cover", "column", "prop", "light", "decor"):
        o["p"] = _mx(op["p"])
        if "yaw" in op:
            o["yaw"] = r1(-op["yaw"])
    elif t == "stairs":
        o["low"] = _mx(op["low"])
        o["high"] = _mx(op["high"])
    elif t == "ladder":
        o["base"] = _mx(op["base"])
        o["out"] = [r1(-op["out"][0]), op["out"][1]]
        o["name"] = op.get("name2", op["name"])
    elif t == "zip":
        o["a"] = _mx(op["a"])
        o["b"] = _mx(op["b"])
        o["name"] = op.get("name2", op["name"])
    elif t == "sling":
        o["pad"] = _mx(op["pad"])
        o["land"] = _mx(op["land"])
        o["name"] = op.get("name2", op["name"])
    elif t == "spawn":
        o["p"] = _mx(op["p"])
        o["yaw"] = r1(-op["yaw"])
        o["team"] = 3 - op["team"]
    else:
        return None
    return o


class Plan:
    def __init__(self, name, ex=72.0, ez=44.0, seed=1):
        self.name = name
        self.ex = ex
        self.ez = ez
        self.ops = []
        self.rng = random.Random(seed)
        self.layout = {}
        self.W = int(round(2 * ex / RES))
        self.H = int(round(2 * ez / RES))

    # ------------------------------------------------------------ authoring
    def add(self, op, mirror=True):
        self.ops.append(op)
        if mirror:
            m = mirror_op(op)
            if m is not None:
                self.ops.append(m)

    def outline(self, half, rails=()):
        """half = west half polygon from the top-centre point, around the west edge, to the bottom-centre point.
        rails = rectangles (x0, z0, x1, z1) on the WEST half: perimeter stretches inside them are low open rails
        (sea beyond) instead of tall walls; they are mirrored to the east half."""
        full = [[r1(p[0]), r1(p[1])] for p in half] + [[r1(-p[0]), r1(p[1])] for p in reversed(half[1:-1])]
        rr = [list(r) for r in rails] + [[r1(-r[2]), r[1], r1(-r[0]), r[3]] for r in rails]
        self.add({"op": "outline", "poly": full, "rails": rr}, mirror=False)

    def free(self, x0, z0, x1, z1, mirror=True):
        self.add({"op": "free", "r": [x0, z0, x1, z1]}, mirror)

    def free_poly(self, poly, mirror=False):
        self.add({"op": "free_poly", "poly": [list(p) for p in poly]}, mirror)

    def room(self, x0, z0, x1, z1, h, doors=None, mat="wall_a", roof="roof", t=0.8, mirror=True, **kw):
        o = {"op": "room", "r": [x0, z0, x1, z1], "h": h, "doors": doors or {}, "mat": mat, "roof": roof, "t": t}
        o.update(kw)
        self.add(o, mirror)

    def block(self, x0, z0, x1, z1, h, mat="wall_a", y0=0.0, mirror=True, **kw):
        o = {"op": "block", "r": [x0, z0, x1, z1], "h": h, "mat": mat, "y0": y0}
        o.update(kw)
        self.add(o, mirror)

    def poly_block(self, poly, h, mat="wall_a", y0=0.0, mirror=True):
        self.add({"op": "poly_block", "poly": [list(p) for p in poly], "h": h, "mat": mat, "y0": y0}, mirror)

    def wall(self, a, b, h, t=0.6, mat="wall_a", y0=0.0, mirror=True):
        self.add({"op": "wall", "a": list(a), "b": list(b), "h": h, "t": t, "mat": mat, "y0": y0}, mirror)

    def cover(self, kind, x, z, size, yaw=0.0, mat="cover", y0=0.0, mirror=True, **kw):
        """kind box: size=[w,h,d]; kind cyl: size=[r,h]."""
        o = {"op": "cover", "kind": kind, "p": [x, z], "size": list(size), "yaw": yaw, "mat": mat, "y0": y0}
        o.update(kw)
        self.add(o, mirror)

    def column(self, x, z, h=5.0, r=0.4, broken=0.0, mat="column", y0=0.0, mirror=True):
        self.add({"op": "column", "p": [x, z], "h": h, "r": r, "broken": broken, "mat": mat, "y0": y0}, mirror)

    def platform(self, poly, top, mat="floor_hi", solid=True, thick=0.4, walk=True, mirror=True, roof=False):
        """Raised walkable area. solid=True fills down to the ground (blocks the ground layer)."""
        if len(poly) == 4 and not isinstance(poly[0], (list, tuple)):
            x0, z0, x1, z1 = poly
            poly = [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]
        self.add({"op": "slab", "poly": [list(p) for p in poly], "top": top, "thick": thick, "mat": mat,
                  "solid": solid, "walk": walk, "roof": roof}, mirror)

    def sunken(self, x0, z0, x1, z1, y, mat="floor_lo", mirror=True):
        self.add({"op": "sunken", "r": [x0, z0, x1, z1], "y": y, "mat": mat}, mirror)

    def stairs(self, low, high, w=4.0, mat="stairs", mirror=True):
        self.add({"op": "stairs", "low": list(low), "high": list(high), "w": w, "mat": mat}, mirror)

    def ladder(self, base, top_y, out, name="L", name2=None, mirror=True):
        self.add({"op": "ladder", "base": list(base), "top": top_y, "out": list(out), "name": name, "name2": name2 or name}, mirror)

    def zip(self, a, b, name="Z", name2=None, mirror=True):
        self.add({"op": "zip", "a": list(a), "b": list(b), "name": name, "name2": name2 or name}, mirror)

    def sling(self, pad, land, flight, name="S", name2=None, mirror=True):
        self.add({"op": "sling", "pad": list(pad), "land": list(land), "flight": flight, "name": name, "name2": name2 or name}, mirror)

    def gate(self, a, a_yaw, b, b_yaw, name="I"):
        self.add({"op": "gate", "a": list(a), "a_yaw": a_yaw, "b": list(b), "b_yaw": b_yaw, "name": name}, mirror=False)

    def prop(self, x, z, size=(2.6, 1.6, 0.5), yaw=0.0, y=0.0, color="F0E8D8", mirror=True):
        self.add({"op": "prop", "p": [x, z], "y": y, "size": list(size), "yaw": yaw, "color": color}, mirror)

    def light(self, x, y, z, color="FFD9A0", energy=1.2, rng=9.0, mirror=True):
        self.add({"op": "light", "p": [x, y, z], "color": color, "energy": energy, "range": rng}, mirror)

    def decor(self, kind, x, z, y=0.0, h=4.0, yaw=0.0, mirror=True, **kw):
        o = {"op": "decor", "kind": kind, "p": [x, y, z], "h": h, "yaw": yaw}
        o.update(kw)
        self.add(o, mirror)

    def spawn_west(self, pts, team=1):
        """pts = [(x, z, yaw)], for team 1 on the west side; the east twin is mirrored (team 2)."""
        for x, z, yaw in pts:
            self.add({"op": "spawn", "p": [x, z], "yaw": yaw, "team": team}, True)

    def set_layout(self, vault1, vault2, stab1, stab2, fields, field_r, field_h):
        self.layout = {"vault1": vault1, "vault2": vault2, "stab1": stab1, "stab2": stab2,
                       "fields": fields, "radius": field_r, "height": field_h}

    def ffa(self, pts):
        self.layout["ffa"] = [list(p) for p in pts]

    def shards(self, pts):
        self.layout["shards"] = [list(p) for p in pts]

    def beacons(self, pts):
        self.layout["beacons"] = [list(p) for p in pts]

    # ------------------------------------------------------------ geometry masks
    def _xy(self, x, z):
        return (x + self.ex) / RES, (z + self.ez) / RES

    def poly_mask(self, pts):
        img = Image.new("L", (self.W, self.H), 0)
        d = ImageDraw.Draw(img)
        d.polygon([self._xy(p[0], p[1]) for p in pts], fill=1, outline=1)
        return np.array(img, dtype=bool)

    def rect_mask(self, x0, z0, x1, z1):
        return self.poly_mask([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])

    def circle_mask(self, x, z, r):
        img = Image.new("L", (self.W, self.H), 0)
        d = ImageDraw.Draw(img)
        cx, cz = self._xy(x, z)
        rr = r / RES
        d.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=1)
        return np.array(img, dtype=bool)

    def obb_mask(self, cx, cz, w, d, yaw_deg):
        t = math.radians(yaw_deg)
        ax = (math.cos(t), -math.sin(t))
        az = (math.sin(t), math.cos(t))
        pts = []
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            pts.append((cx + ax[0] * sx * w / 2 + az[0] * sz * d / 2, cz + ax[1] * sx * w / 2 + az[1] * sz * d / 2))
        return self.poly_mask(pts)

    def seg_mask(self, a, b, t):
        dx, dz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dz) or 1e-6
        nx, nz = -dz / L * t / 2, dx / L * t / 2
        ex_, ez_ = dx / L * t / 4, dz / L * t / 4
        a2 = (a[0] - ex_, a[1] - ez_)
        b2 = (b[0] + ex_, b[1] + ez_)
        return self.poly_mask([(a2[0] + nx, a2[1] + nz), (b2[0] + nx, b2[1] + nz), (b2[0] - nx, b2[1] - nz), (a2[0] - nx, a2[1] - nz)])

    # ------------------------------------------------------------ derived solid fill
    def _outline_mask(self):
        for o in self.ops:
            if o["op"] == "outline":
                return self.poly_mask(o["poly"])
        raise RuntimeError("no outline")

    def reserved_mask(self):
        m = np.zeros((self.H, self.W), dtype=bool)
        for o in self.ops:
            t = o["op"]
            if t == "free":
                m |= self.rect_mask(*o["r"])
            elif t == "free_poly":
                m |= self.poly_mask(o["poly"])
            elif t == "room":
                m |= self.rect_mask(*o["r"])
            elif t == "slab" and o.get("solid"):
                m |= self.poly_mask(o["poly"])
            elif t == "sunken":
                m |= self.rect_mask(*o["r"])
        return m

    def solidify(self, h=(8.0, 11.0), maxdim=15.0, mats=("wall_a", "wall_b", "wall_c"), zones=(), minside=0.9):
        """Fill every outline cell that is not free/room/platform/sunken with building masses."""
        self.ops = [o for o in self.ops if not o.get("derived")]
        inside = self._outline_mask()
        res = self.reserved_mask()
        solid = inside & ~res
        # 1 m grid decomposition
        n = 1.0
        gx0 = -self.ex
        gz0 = -self.ez
        nx = int(round(2 * self.ex / n))
        nz = int(round(2 * self.ez / n))
        cell = np.zeros((nz, nx), dtype=bool)
        step = int(round(n / RES))
        for iz in range(nz):
            for ix in range(nx):
                sub = solid[iz * step:(iz + 1) * step, ix * step:(ix + 1) * step]
                cell[iz, ix] = sub.mean() > 0.5
        used = np.zeros_like(cell)
        rects = []
        for iz in range(nz):
            ix = 0
            while ix < nx:
                if cell[iz, ix] and not used[iz, ix]:
                    jx = ix
                    while jx < nx and cell[iz, jx] and not used[iz, jx]:
                        jx += 1
                    jz = iz + 1
                    while jz < nz and cell[jz, ix:jx].all() and not used[jz, ix:jx].any():
                        jz += 1
                    used[iz:jz, ix:jx] = True
                    rects.append([gx0 + ix * n, gz0 + iz * n, gx0 + jx * n, gz0 + jz * n])
                    ix = jx
                else:
                    ix += 1
        out = []
        for r in rects:
            w, d = r[2] - r[0], r[3] - r[1]
            if min(w, d) < minside:
                continue
            kx = max(1, int(math.ceil(w / maxdim)))
            kz = max(1, int(math.ceil(d / maxdim)))
            for i in range(kx):
                for j in range(kz):
                    x0 = r[0] + w * i / kx
                    x1 = r[0] + w * (i + 1) / kx
                    z0 = r[1] + d * j / kz
                    z1 = r[1] + d * (j + 1) / kz
                    out.append([r1(x0), r1(z0), r1(x1), r1(z1)])
        for r in out:
            cx, cz = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
            hh = self.rng.uniform(h[0], h[1])
            mat = mats[int(abs(math.floor(cx / 7.0) * 31 + math.floor(cz / 7.0) * 17)) % len(mats)]
            for z in zones:
                zx0, zz0, zx1, zz1 = z["r"]
                if zx0 <= cx <= zx1 and zz0 <= cz <= zz1:
                    hh = self.rng.uniform(*z.get("h", h))
                    mat = z.get("mat", mat)
            self.ops.append({"op": "block", "r": r, "h": r1(hh), "mat": mat, "y0": 0.0, "derived": True, "fill": True})
        return len(out)

    # ------------------------------------------------------------ rasterised model
    def build(self):
        om = self._outline_mask()
        # the polygon fill includes the boundary pixel row: erode by 2 cells so edge cells are solid wall
        for _ in range(2):
            om = om & np.roll(om, 1, 0) & np.roll(om, -1, 0) & np.roll(om, 1, 1) & np.roll(om, -1, 1)
        self.outline_m = om
        holes = np.zeros_like(self.outline_m)
        self.layer_y = [0.0]
        region = {}        # y -> mask of walkable surface
        blockers = []      # (mask, y0, y1)
        sunken = []
        for o in self.ops:
            t = o["op"]
            if t == "sunken":
                holes |= self.rect_mask(*o["r"])
                y = o["y"]
                region[y] = region.get(y, np.zeros_like(holes)) | self.rect_mask(*o["r"])
            elif t == "slab" and o.get("walk", True):
                y = o["top"]
                region[y] = region.get(y, np.zeros_like(holes)) | self.poly_mask(o["poly"])
                if o.get("solid"):
                    blockers.append((self.poly_mask(o["poly"]), -9.0, y))
            elif t == "block":
                y0 = o.get("y0", 0.0)
                blockers.append((self.rect_mask(*o["r"]), y0, y0 + o["h"]))
            elif t == "poly_block":
                y0 = o.get("y0", 0.0)
                blockers.append((self.poly_mask(o["poly"]), y0, y0 + o["h"]))
            elif t == "wall":
                y0 = o.get("y0", 0.0)
                blockers.append((self.seg_mask(o["a"], o["b"], o["t"]), y0, y0 + o["h"]))
            elif t == "room":
                x0, z0, x1, z1 = o["r"]
                tt = o["t"]
                sides = {
                    "n": ((x0, z0 + tt / 2), (x1, z0 + tt / 2)),
                    "s": ((x0, z1 - tt / 2), (x1, z1 - tt / 2)),
                    "w": ((x0 + tt / 2, z0), (x0 + tt / 2, z1)),
                    "e": ((x1 - tt / 2, z0), (x1 - tt / 2, z1)),
                }
                fl = o.get("floor", 0.0)
                for side, (a, b) in sides.items():
                    L = math.hypot(b[0] - a[0], b[1] - a[1])
                    d = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
                    cuts = []
                    for off, w in o["doors"].get(side, []):
                        c = L / 2 + off
                        cuts.append((c - w / 2, c + w / 2))
                    cuts.sort()
                    tcur = 0.0
                    for c0, c1 in cuts + [(L, L)]:
                        if c0 - tcur > 0.2:
                            pa = (a[0] + d[0] * tcur, a[1] + d[1] * tcur)
                            pb = (a[0] + d[0] * c0, a[1] + d[1] * c0)
                            blockers.append((self.seg_mask(pa, pb, tt), fl, fl + o["h"]))
                        tcur = c1
            elif t == "cover":
                hgt = o["size"][1] if o["kind"] == "box" else o["size"][1]
                y0 = o.get("y0", 0.0)
                if hgt <= STEP_H:
                    continue
                if o["kind"] == "box":
                    m = self.obb_mask(o["p"][0], o["p"][1], o["size"][0], o["size"][2], o["yaw"])
                else:
                    m = self.circle_mask(o["p"][0], o["p"][1], o["size"][0])
                blockers.append((m, y0, y0 + hgt))
            elif t == "column":
                y0 = o.get("y0", 0.0)
                blockers.append((self.circle_mask(o["p"][0], o["p"][1], o["r"] * 1.1), y0, y0 + o["h"] * (1.0 - o.get("broken", 0.0)) + 0.6))
        self.blockers = blockers
        self.region = {0.0: self.outline_m & ~holes}
        for y, m in region.items():
            ry = round(y, 2)
            self.region[ry] = (self.region[ry] | m) if ry in self.region else m
        self.layer_y = sorted(self.region.keys())
        self.walk = {}
        self.sight = {}
        disk = []
        rc = int(math.ceil(AGENT_R / RES))
        for dz in range(-rc, rc + 1):
            for dx in range(-rc, rc + 1):
                if math.hypot(dx, dz) * RES <= AGENT_R + 1e-6:
                    disk.append((dz, dx))
        for y in self.layer_y:
            blk = np.zeros_like(self.outline_m)
            for m, y0, y1 in blockers:
                if y0 < y + CLEAR_H and y1 > y + STEP_H + 0.05:
                    blk |= m
            infl = blk.copy()
            for dz, dx in disk:
                if dz or dx:
                    infl |= np.roll(np.roll(blk, dz, axis=0), dx, axis=1)
            self.walk[y] = self.region[y] & ~infl
            # sight blockers at the eye height of this layer (outside the outline is a solid wall)
            eye = y + EYE
            sb = np.zeros_like(self.outline_m)
            for m, y0, y1 in blockers:
                if y0 <= eye <= y1:
                    sb |= m
            if y == 0.0:
                sb |= ~self.outline_m
            elif y < 0.0:
                sb |= ~self.region[y]          # sunken: the surrounding ground is above eye level
            else:
                sb |= ~(self.region[y] | self.outline_m)
            self.sight[y] = sb
        # connections between layers
        self.links = []
        for o in self.ops:
            if o["op"] == "stairs":
                self.links.append(("stairs", o["low"], o["high"], o))
            elif o["op"] == "ladder":
                b = o["base"]
                out = o["out"]
                top = [b[0] - out[0] * 1.4, o["top"], b[2] - out[1] * 1.4] if len(b) == 3 else None
                self.links.append(("ladder", [b[0] + out[0] * 0.9, b[1], b[2] + out[1] * 0.9], top, o))

    # ------------------------------------------------------------ routing
    def _layer_of(self, y):
        best = min(self.layer_y, key=lambda ly: abs(ly - y))
        return best

    def _cell(self, x, z):
        return int(round((z + self.ez) / RES - 0.5)), int(round((x + self.ex) / RES - 0.5))

    def _nearest_walk(self, layer, x, z, maxr=3.0):
        iz, ix = self._cell(x, z)
        w = self.walk[layer]
        if 0 <= iz < self.H and 0 <= ix < self.W and w[iz, ix]:
            return iz, ix
        rr = int(maxr / RES)
        best = None
        bd = 1e9
        for dz in range(-rr, rr + 1):
            for dx in range(-rr, rr + 1):
                z2, x2 = iz + dz, ix + dx
                if 0 <= z2 < self.H and 0 <= x2 < self.W and w[z2, x2]:
                    d = dz * dz + dx * dx
                    if d < bd:
                        bd = d
                        best = (z2, x2)
        return best

    # ------------------------------------------------------------ placement checks
    def clearance(self, x, y, z):
        """Distance (m) from a point to the nearest non-walkable cell on its layer (0 if the point itself is not walkable)."""
        layer = self._layer_of(y)
        w = self.walk[layer]
        iz, ix = self._cell(x, z)
        if not (0 <= iz < self.H and 0 <= ix < self.W) or not w[iz, ix]:
            return 0.0
        rr = int(6.0 / RES)
        z0, z1 = max(0, iz - rr), min(self.H, iz + rr + 1)
        x0, x1 = max(0, ix - rr), min(self.W, ix + rr + 1)
        sub = ~w[z0:z1, x0:x1]
        if not sub.any():
            return 6.0
        zz, xx = np.nonzero(sub)
        d = np.hypot((zz + z0 - iz), (xx + x0 - ix)) * RES
        return float(d.min())

    def check_points(self, min_clear=1.0):
        """Every gameplay point must sit on walkable ground with room around it (the navmesh snaps to its island otherwise)."""
        pts = []
        L = self.layout
        for k in ("vault1", "vault2", "stab1", "stab2"):
            if k in L:
                pts.append((k, L[k]))
        for i, f in enumerate(L.get("fields", [])):
            pts.append(("field%d" % i, f))
        for i, f in enumerate(L.get("shards", [])):
            pts.append(("shard%d" % i, f))
        for i, f in enumerate(L.get("beacons", [])):
            pts.append(("beacon%d" % i, f))
        for i, f in enumerate(L.get("ffa", [])):
            pts.append(("ffa%d" % i, [f[0], self.ground_y(f[0], f[1]), f[1]]))
        for o in self.ops:
            if o["op"] == "spawn":
                pts.append(("spawn_t%d" % o["team"], [o["p"][0], self.ground_y(o["p"][0], o["p"][1]), o["p"][1]]))
        bad = []
        for name, p in pts:
            c = self.clearance(p[0], p[1], p[2])
            critical = name.startswith(("vault", "stab", "field", "spawn"))
            if c < (min_clear if critical else 0.45):
                bad.append((name, [p[0], p[1], p[2]], round(c, 2)))
        return bad

    def ground_y(self, x, z):
        best = 0.0
        for o in self.ops:
            if o["op"] == "slab" and o.get("walk", True):
                pts = [(q[0], q[1]) for q in o["poly"]]
                xs = [q[0] for q in pts]
                zs = [q[1] for q in pts]
                if min(xs) <= x <= max(xs) and min(zs) <= z <= max(zs):
                    best = max(best, o["top"])
            elif o["op"] == "sunken":
                r = o["r"]
                if r[0] <= x <= r[2] and r[1] <= z <= r[3]:
                    best = min(best, o["y"])
        return best

    def route(self, pts, carrier=True):
        """Shortest walking distance through 3D waypoints [(x,y,z), ...]. Returns (length, polyline) or (None, None)."""
        total = 0.0
        poly = []
        for a, b in zip(pts[:-1], pts[1:]):
            d, p = self._dijkstra(a, b, carrier)
            if d is None:
                return None, None
            total += d
            poly += p
        return total, poly

    def _dijkstra(self, a, b, carrier):
        la, lb = self._layer_of(a[1]), self._layer_of(b[1])
        s = self._nearest_walk(la, a[0], a[2])
        g = self._nearest_walk(lb, b[0], b[2])
        if s is None or g is None:
            return None, None
        start = (la, s[0], s[1])
        goal = (lb, g[0], g[1])
        # inter-layer edges
        extra = {}
        for kind, lo, hi, o in self.links:
            if hi is None:
                continue
            if kind == "ladder" and carrier:
                continue
            l0, l1 = self._layer_of(lo[1]), self._layer_of(hi[1])
            c0 = self._nearest_walk(l0, lo[0], lo[2], 3.0)
            c1 = self._nearest_walk(l1, hi[0], hi[2], 3.0)
            if c0 is None or c1 is None:
                continue
            cost = math.sqrt((hi[0] - lo[0]) ** 2 + (hi[2] - lo[2]) ** 2 + (hi[1] - lo[1]) ** 2)
            if kind == "ladder":
                cost = abs(hi[1] - lo[1]) * 1.4 + 2.0
            extra.setdefault((l0, c0[0], c0[1]), []).append(((l1, c1[0], c1[1]), cost))
            extra.setdefault((l1, c1[0], c1[1]), []).append(((l0, c0[0], c0[1]), cost))
        dist = {start: 0.0}
        prev = {}
        pq = [(0.0, start)]
        SQ = math.sqrt(2.0) * RES
        nbrs = [(-1, 0, RES), (1, 0, RES), (0, -1, RES), (0, 1, RES), (-1, -1, SQ), (-1, 1, SQ), (1, -1, SQ), (1, 1, SQ)]
        while pq:
            d, node = heapq.heappop(pq)
            if node == goal:
                break
            if d > dist.get(node, 1e18):
                continue
            ly, iz, ix = node
            w = self.walk[ly]
            for dz, dx, c in nbrs:
                z2, x2 = iz + dz, ix + dx
                if 0 <= z2 < self.H and 0 <= x2 < self.W and w[z2, x2]:
                    if dz and dx and not (w[iz + dz, ix] and w[iz, ix + dx]):
                        continue
                    nn = (ly, z2, x2)
                    nd = d + c
                    if nd < dist.get(nn, 1e18):
                        dist[nn] = nd
                        prev[nn] = node
                        heapq.heappush(pq, (nd, nn))
            for nn, c in extra.get(node, ()):
                nd = d + c
                if nd < dist.get(nn, 1e18):
                    dist[nn] = nd
                    prev[nn] = node
                    heapq.heappush(pq, (nd, nn))
        if goal not in dist:
            return None, None
        path = []
        n = goal
        while n in prev:
            path.append(n)
            n = prev[n]
        path.append(start)
        path.reverse()
        poly = [((ix + 0.5) * RES - self.ex, (iz + 0.5) * RES - self.ez, ly) for ly, iz, ix in path]
        return dist[goal], poly

    # ------------------------------------------------------------ sight analysis
    def sight_stats(self, layer=0.0, step=2.0, rays=72, rng_m=80.0):
        w = self.walk[layer]
        sb = self.sight[layer]
        ys, xs = np.where(w)
        pts = []
        stride = max(1, int(step / RES))
        for iz, ix in zip(ys, xs):
            if iz % stride == 0 and ix % stride == 0:
                pts.append((ix, iz))
        if not pts:
            return None
        P = np.array(pts, dtype=np.float64)
        angs = np.linspace(0, 2 * math.pi, rays, endpoint=False)
        steps = int(rng_m / (RES * 0.8))
        dmax = np.zeros((len(P), rays))
        alive = np.ones((len(P), rays), dtype=bool)
        sbi = sb
        for k in range(1, steps + 1):
            dist = k * RES * 0.8
            px = P[:, 0:1] + np.cos(angs)[None, :] * dist / RES
            pz = P[:, 1:2] + np.sin(angs)[None, :] * dist / RES
            ix = np.clip(px.astype(int), 0, self.W - 1)
            iz = np.clip(pz.astype(int), 0, self.H - 1)
            hit = sbi[iz, ix] | (px < 0) | (px >= self.W) | (pz < 0) | (pz >= self.H)
            newly = alive & hit
            dmax[newly] = dist
            alive &= ~hit
        dmax[alive] = rng_m
        maxd = dmax.max(axis=1)
        meand = dmax.mean(axis=1)
        self._sight_pts = (P, maxd, meand, dmax)
        st = {
            "points": len(P),
            "maxd_p50": float(np.percentile(maxd, 50)), "maxd_p75": float(np.percentile(maxd, 75)),
            "maxd_p90": float(np.percentile(maxd, 90)), "maxd_p99": float(np.percentile(maxd, 99)),
            "mean_sight": float(meand.mean()),
            "rays_over_25": float((dmax > 25).mean()), "rays_over_35": float((dmax > 35).mean()),
            "points_over_35": float((maxd > 35).mean()), "points_over_50": float((maxd > 50).mean()),
        }
        # worst points
        order = np.argsort(-maxd)[:12]
        st["worst"] = []
        for i in order:
            k = int(np.argmax(dmax[i]))
            st["worst"].append((float(round(P[i, 0] * RES - self.ex, 1)), float(round(P[i, 1] * RES - self.ez, 1)), float(round(maxd[i], 1)), int(round(math.degrees(angs[k])))))
        # long lines grouped by 8 m cells of their start point (to see regions, not single points)
        reg = {}
        for i in range(len(P)):
            if maxd[i] > 38:
                key = (int(math.floor((P[i, 0] * RES - self.ex) / 8.0)) * 8, int(math.floor((P[i, 1] * RES - self.ez) / 8.0)) * 8)
                reg[key] = reg.get(key, 0) + 1
        st["long_regions"] = sorted(reg.items(), key=lambda kv: -kv[1])[:10]
        return st

    def traffic(self, thr=28.0, bin_m=4.0, top=10):
        """Which 4 m cells do the long rays cross most? (best places for a sight-breaking blocker)"""
        P, maxd, meand, dmax = self._sight_pts
        angs = np.linspace(0, 2 * math.pi, dmax.shape[1], endpoint=False)
        cnt = {}
        idx = np.argwhere(dmax > thr)
        for i, k in idx:
            L = dmax[i, k]
            n = int(L)
            for t in range(2, n - 1, 2):
                x = P[i, 0] * RES - self.ex + math.cos(angs[k]) * t
                z = P[i, 1] * RES - self.ez + math.sin(angs[k]) * t
                key = (int(math.floor(x / bin_m)) * bin_m + bin_m / 2, int(math.floor(z / bin_m)) * bin_m + bin_m / 2)
                cnt[key] = cnt.get(key, 0) + 1
        self._traffic = cnt
        return sorted(cnt.items(), key=lambda kv: -kv[1])[:top]

    def visible_fraction(self, x, z, layer=0.0, rng_m=80.0, step=2.0):
        """Share of walkable sample points (same layer) with line of sight to (x, z) at eye height."""
        w = self.walk[layer]
        sb = self.sight[layer]
        ys, xs = np.where(w)
        stride = max(1, int(step / RES))
        sel = [(ix, iz) for iz, ix in zip(ys, xs) if iz % stride == 0 and ix % stride == 0]
        if not sel:
            return 0.0
        P = np.array(sel, dtype=np.float64)
        sx, sz = (x + self.ex) / RES, (z + self.ez) / RES
        dx = P[:, 0] - sx
        dz = P[:, 1] - sz
        dist = np.hypot(dx, dz) * RES
        n = int(rng_m / (RES * 0.8))
        vis = dist <= rng_m
        for k in range(1, n):
            f = k / n
            ix = np.clip((sx + dx * f).astype(int), 0, self.W - 1)
            iz = np.clip((sz + dz * f).astype(int), 0, self.H - 1)
            vis &= ~sb[iz, ix] | (f > 0.999)
        return float(vis.mean())

    # ------------------------------------------------------------ drawing
    def render(self, path, scale=7, heat=False, routes=None, label=True):
        S = scale
        W, H = int(2 * self.ex * S), int(2 * self.ez * S)
        img = Image.new("RGB", (W, H), (22, 24, 30))
        d = ImageDraw.Draw(img, "RGBA")

        def P(x, z):
            return ((x + self.ex) * S, (z + self.ez) * S)

        def poly(pts, fill=None, outline=None):
            d.polygon([P(*p) for p in pts], fill=fill, outline=outline)

        for o in self.ops:
            if o["op"] == "outline":
                poly(o["poly"], fill=(70, 66, 58, 255))
        for o in self.ops:
            t = o["op"]
            if t == "sunken":
                x0, z0, x1, z1 = o["r"]
                poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], fill=(40, 90, 120, 255))
        for o in self.ops:
            t = o["op"]
            if t == "slab" and o.get("walk", True):
                top = o["top"]
                col = (70, 130, 150, 255) if top > 0 else (60, 100, 90, 255)
                if top >= 4.5:
                    col = (150, 120, 60, 255)
                poly(o["poly"], fill=col)
        for o in self.ops:
            t = o["op"]
            if t == "block":
                x0, z0, x1, z1 = o["r"]
                h = o["h"]
                g = int(105 + min(h, 14) * 7)
                poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], fill=(g, g - 6, g - 14, 255), outline=(30, 28, 26, 255))
            elif t == "poly_block":
                poly(o["poly"], fill=(150, 140, 125, 255), outline=(30, 28, 26, 255))
        for o in self.ops:
            t = o["op"]
            if t == "room":
                x0, z0, x1, z1 = o["r"]
                poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], fill=(96, 84, 70, 255))
                tt = o["t"]
                for side, (a, b) in {"n": ((x0, z0 + tt / 2), (x1, z0 + tt / 2)), "s": ((x0, z1 - tt / 2), (x1, z1 - tt / 2)),
                                      "w": ((x0 + tt / 2, z0), (x0 + tt / 2, z1)), "e": ((x1 - tt / 2, z0), (x1 - tt / 2, z1))}.items():
                    L = math.hypot(b[0] - a[0], b[1] - a[1])
                    dv = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
                    cuts = sorted((L / 2 + off - w / 2, L / 2 + off + w / 2) for off, w in o["doors"].get(side, []))
                    tcur = 0.0
                    for c0, c1 in cuts + [(L, L)]:
                        if c0 > tcur:
                            pa = (a[0] + dv[0] * tcur, a[1] + dv[1] * tcur)
                            pb = (a[0] + dv[0] * c0, a[1] + dv[1] * c0)
                            d.line([P(*pa), P(*pb)], fill=(235, 220, 190, 255), width=max(2, int(tt * S)))
                        tcur = c1
        for o in self.ops:
            t = o["op"]
            if t == "wall":
                d.line([P(*o["a"]), P(*o["b"])], fill=(235, 220, 190, 255), width=max(2, int(o["t"] * S)))
            elif t == "cover":
                if o["kind"] == "box":
                    cx, cz = o["p"]
                    w, h, dd = o["size"]
                    tt = math.radians(o["yaw"])
                    ax = (math.cos(tt), -math.sin(tt))
                    az = (math.sin(tt), math.cos(tt))
                    pts = [(cx + ax[0] * sx * w / 2 + az[0] * sz * dd / 2, cz + ax[1] * sx * w / 2 + az[1] * sz * dd / 2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                    poly(pts, fill=(230, 150, 70, 255) if h > 1.7 else (200, 170, 90, 255))
                else:
                    cx, cz = o["p"]
                    r = o["size"][0]
                    d.ellipse([P(cx - r, cz - r), P(cx + r, cz + r)], fill=(215, 160, 80, 255))
            elif t == "column":
                cx, cz = o["p"]
                r = o["r"]
                d.ellipse([P(cx - r, cz - r), P(cx + r, cz + r)], fill=(245, 240, 225, 255))
            elif t == "stairs":
                lo, hi = o["low"], o["high"]
                d.line([P(lo[0], lo[2]), P(hi[0], hi[2])], fill=(255, 230, 80, 255), width=max(3, int(o["w"] * S * 0.7)))
            elif t == "ladder":
                b = o["base"]
                d.rectangle([P(b[0] - 0.7, b[2] - 0.7), P(b[0] + 0.7, b[2] + 0.7)], fill=(255, 120, 40, 255))
            elif t == "zip":
                d.line([P(o["a"][0], o["a"][2]), P(o["b"][0], o["b"][2])], fill=(255, 200, 60, 200), width=2)
            elif t == "sling":
                d.line([P(o["pad"][0], o["pad"][2]), P(o["land"][0], o["land"][2])], fill=(255, 90, 60, 200), width=2)
                d.ellipse([P(o["pad"][0] - 1.5, o["pad"][2] - 1.5), P(o["pad"][0] + 1.5, o["pad"][2] + 1.5)], fill=(255, 90, 60, 255))
            elif t == "gate":
                for key in ("a", "b"):
                    g = o[key]
                    d.ellipse([P(g[0] - 1.8, g[2] - 1.8), P(g[0] + 1.8, g[2] + 1.8)], outline=(80, 255, 220, 255), width=3)
            elif t == "prop":
                cx, cz = o["p"]
                d.rectangle([P(cx - 1.2, cz - 0.6), P(cx + 1.2, cz + 0.6)], fill=(120, 200, 255, 255))
        if heat and hasattr(self, "_sight_pts"):
            Pn, maxd, meand, _ = self._sight_pts
            for (ix, iz), m in zip(Pn, maxd):
                col = (60, 200, 90, 170) if m < 18 else (230, 220, 60, 170) if m < 30 else (240, 140, 40, 190) if m < 45 else (235, 50, 50, 210)
                x = ix * RES - self.ex
                z = iz * RES - self.ez
                d.rectangle([P(x - 0.8, z - 0.8), P(x + 0.8, z + 0.8)], fill=col)
        if heat and hasattr(self, "_sight_pts"):
            Pn, maxd, meand, dm = self._sight_pts
            angs = np.linspace(0, 2 * math.pi, dm.shape[1], endpoint=False)
            order = np.argsort(-dm.max(axis=1))[:60]
            for i in order[::2]:
                k = int(np.argmax(dm[i]))
                x0 = Pn[i, 0] * RES - self.ex
                z0 = Pn[i, 1] * RES - self.ez
                x1 = x0 + math.cos(angs[k]) * dm[i, k]
                z1 = z0 + math.sin(angs[k]) * dm[i, k]
                d.line([P(x0, z0), P(x1, z1)], fill=(255, 0, 255, 150), width=1)
        if routes:
            colors = [(255, 70, 70, 255), (90, 255, 120, 255), (80, 170, 255, 255), (255, 80, 255, 255)]
            for i, (name, poly_pts) in enumerate(routes.items()):
                col = colors[i % len(colors)]
                pp = [P(p[0], p[1]) for p in poly_pts[::6]]
                if len(pp) > 1:
                    d.line(pp, fill=col, width=3)
        L = self.layout
        if L:
            def mark(p, col, txt):
                d.ellipse([P(p[0] - 2, p[2] - 2), P(p[0] + 2, p[2] + 2)], fill=col, outline=(255, 255, 255, 255))
                if label:
                    d.text(P(p[0] + 2.5, p[2] - 2), txt, fill=(255, 255, 255, 255))
            mark(L["vault1"], (255, 210, 60, 255), "V1")
            mark(L["vault2"], (255, 210, 60, 255), "V2")
            mark(L["stab1"], (90, 255, 200, 255), "S1")
            mark(L["stab2"], (90, 255, 200, 255), "S2")
            for i, f in enumerate(L["fields"]):
                d.ellipse([P(f[0] - L["radius"], f[2] - L["radius"]), P(f[0] + L["radius"], f[2] + L["radius"])], outline=(120, 255, 180, 255), width=2)
                if label:
                    d.text(P(f[0] - 2, f[2] - 2), "F%d" % (i + 1), fill=(120, 255, 180, 255))
        for o in self.ops:
            if o["op"] == "spawn":
                d.ellipse([P(o["p"][0] - 0.8, o["p"][1] - 0.8), P(o["p"][0] + 0.8, o["p"][1] + 0.8)], fill=(80, 160, 255, 255) if o["team"] == 1 else (255, 90, 90, 255))
        # grid
        for gx in range(-int(self.ex), int(self.ex) + 1, 10):
            d.line([P(gx, -self.ez), P(gx, self.ez)], fill=(255, 255, 255, 28))
        for gz in range(-int(self.ez), int(self.ez) + 1, 10):
            d.line([P(-self.ex, gz), P(self.ex, gz)], fill=(255, 255, 255, 28))
        img.save(path)

    # ------------------------------------------------------------ export
    def emit_gd(self, path, extra_const=""):
        ops = []
        for o in self.ops:
            if o["op"] in ("free", "free_poly"):
                continue
            c = {k: v for k, v in o.items() if k not in ("derived", "name2")}
            ops.append(c)
        body = json.dumps(ops, separators=(",", ":"))
        lay = json.dumps(self.layout, separators=(",", ":"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("extends RefCounted\n")
            f.write("## GENERATED by tools/mapproto (%s.py). Do not edit by hand: edit the plan and re-run gen.\n" % self.name)
            f.write("const EXTENT := Vector2(%s, %s)\n" % (self.ex, self.ez))
            f.write("const LAYOUT := %s\n" % lay)
            f.write("const OPS := %s\n" % body)
            if extra_const:
                f.write(extra_const)
        return len(ops)


# ---------------------------------------------------------------- reporting helpers
def report(plan, carrier_pts=None, sight_layers=(0.0,), spawn_xz=None, heat_png=None, plan_png=None):
    plan.build()
    print("== %s  ops=%d  layers=%s" % (plan.name, len(plan.ops), plan.layer_y))
    routes = {}
    if plan.layout:
        L = plan.layout
        v2, s1 = L["vault2"], L["stab1"]
        fa, fb = L["fields"][0], L["fields"][1]
        tests = {
            "direct": [v2, s1],
            "via_B": [v2, fb, s1], "via_A": [v2, fa, s1],
            "via_B_then_A": [v2, fb, fa, s1],
        }
        for k, pts in tests.items():
            d, pl = plan.route(pts)
            if d is None:
                print("   route %-14s UNREACHABLE" % k)
                continue
            routes[k] = pl
            carry = d / 4.2
            print("   route %-14s %6.1f m  carry %5.1f s  %s" % (k, d, carry, ""))
        # bot route (ladders allowed)
        d, _ = plan.route([L["vault2"], L["stab1"]], carrier=False)
        if d is not None:
            print("   (bot, ladders ok) direct %6.1f m" % d)
    for ly in sight_layers:
        if ly not in plan.walk:
            continue
        st = plan.sight_stats(ly)
        if st is None:
            continue
        print("   sight layer %.1f: pts=%d  max-ray p50=%.0f p75=%.0f p90=%.0f p99=%.0f  mean=%.1f  rays>25m=%.1f%% rays>35m=%.1f%%  pts>35m=%.0f%% pts>50m=%.0f%%" % (
            ly, st["points"], st["maxd_p50"], st["maxd_p75"], st["maxd_p90"], st["maxd_p99"], st["mean_sight"],
            st["rays_over_25"] * 100, st["rays_over_35"] * 100, st["points_over_35"] * 100, st["points_over_50"] * 100))
        print("       longest sightlines (x, z, metres, heading deg: 0=+x 90=+z):", st["worst"][:8])
        print("       regions with >38 m lines (8 m cells, count):", st["long_regions"][:8])
        print("       busiest cells for long rays (x, z) -> count:", [((float(a), float(b)), c) for (a, b), c in plan.traffic()][:8])
        if ly == 0.0 and heat_png:
            plan.render(heat_png, heat=True, routes=routes)
    if spawn_xz:
        for nm, (x, z) in spawn_xz.items():
            print("   visible from %-10s: %.1f%% of walkable points" % (nm, plan.visible_fraction(x, z) * 100))
    if plan_png:
        plan.render(plan_png, routes=routes)
    bad = plan.check_points()
    if bad:
        print("   !! PLACEMENT PROBLEMS (point, position, clearance m):")
        for b in bad:
            print("      ", b)
    else:
        print("   placement check: all gameplay points are on open ground with >=1.2 m clearance")
    free_cells = plan.walk[0.0].sum() * RES * RES
    inside = plan.outline_m.sum() * RES * RES
    print("   walkable ground area %.0f m2 of %.0f m2 inside outline (%.0f%%)" % (free_cells, inside, 100 * free_cells / inside))
    return routes
