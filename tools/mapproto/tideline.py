"""TIDELINE EXCHANGE - street plan (west half authored, east half mirrored).

Vertical dockyard.  A tall EXCHANGE HALL (14 m ceiling) holds the centre with galleries at y 5 and two crossing
cables; a north QUAY runs under a GANTRY at y 5; a sunken LOADING CHANNEL (y -2.4) with weirs (S-bend gaps) holds both
Stability Fields.  Warehouses carry indoor passages between quay and yard.  Carriers cannot climb ladders or ride
cables: stairs and ramps only.

  direct : enemy bay -> yard street -> hall (ground) -> yard street -> home bay -> south lane -> home berth
  channel: enemy bay south door -> south lane -> east channel stairs -> weirs/fields -> west channel stairs -> berth
  north  : enemy bay north door / hall north lane -> quay -> west corner -> west exit (defenders' flank)
  upper  : gantry (y 5) over the quay, hall galleries (y 5), bay mezzanines (y 4): ladders for non-carriers
"""
import math
import os
import sys
sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0])
from proto import Plan, report

TY = 5.0     # gantry / gallery height
CH = -2.4    # channel floor


def solid_rects(P, layer=0.0):
    """Axis-aligned ground-level solids (blocks, room wall segments, walls, covers, columns) as
    [x0, z0, x1, z1, op, tag]; used to find and close slits narrower than a corridor."""
    out = []
    for o in P.ops:
        t = o["op"]
        if t == "block":
            y0 = o.get("y0", 0.0)
            if y0 <= layer + 0.6 and y0 + o["h"] > layer + 0.6:
                r = o["r"]
                out.append([r[0], r[1], r[2], r[3], o, "block"])
        elif t == "room":
            x0, z0, x1, z1 = o["r"]
            tt = o["t"]
            fl = o.get("floor", 0.0)
            sides = {"n": ((x0, z0 + tt / 2), (x1, z0 + tt / 2)), "s": ((x0, z1 - tt / 2), (x1, z1 - tt / 2)),
                     "w": ((x0 + tt / 2, z0), (x0 + tt / 2, z1)), "e": ((x1 - tt / 2, z0), (x1 - tt / 2, z1))}
            for k, (a, b) in sides.items():
                L = math.hypot(b[0] - a[0], b[1] - a[1])
                d = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
                cuts = sorted((L / 2 + off - w / 2, L / 2 + off + w / 2) for off, w in o["doors"].get(k, []))
                tc = 0.0
                for c0, c1 in cuts + [(L, L)]:
                    if c0 - tc > 0.2:
                        pa = (a[0] + d[0] * tc, a[1] + d[1] * tc)
                        pb = (a[0] + d[0] * c0, a[1] + d[1] * c0)
                        hw = tt / 2
                        if k in "ns":
                            out.append([pa[0], pa[1] - hw, pb[0], pb[1] + hw, o, "roomwall"])
                        else:
                            out.append([pa[0] - hw, pa[1], pb[0] + hw, pb[1], o, "roomwall"])
                    tc = c1
        elif t == "wall":
            a, b, tt = o["a"], o["b"], o["t"]
            if o.get("y0", 0.0) <= layer + 0.6 < o.get("y0", 0.0) + o["h"]:
                if abs(a[0] - b[0]) < 1e-6:
                    out.append([a[0] - tt / 2, min(a[1], b[1]), a[0] + tt / 2, max(a[1], b[1]), o, "wall"])
                elif abs(a[1] - b[1]) < 1e-6:
                    out.append([min(a[0], b[0]), a[1] - tt / 2, max(a[0], b[0]), a[1] + tt / 2, o, "wall"])
        elif t == "cover" and o["kind"] == "box" and o["size"][1] > 0.6 and o.get("y0", 0.0) <= layer + 0.6:
            sz, p = o["size"], o["p"]
            yaw = o.get("yaw", 0.0) % 180
            if yaw < 1:
                w, d = sz[0], sz[2]
            elif abs(yaw - 90) < 1:
                w, d = sz[2], sz[0]
            else:
                continue
            out.append([p[0] - w / 2, p[1] - d / 2, p[0] + w / 2, p[1] + d / 2, o, "cover"])
        elif t == "column" and o.get("y0", 0.0) <= layer + 0.6:
            p, r = o["p"], o["r"] * 1.1
            out.append([p[0] - r, p[1] - r, p[0] + r, p[1] + r, o, "column"])
    return out


def seal_slits(P, maxgap=1.25, minlen=0.4):
    """proto.solidify leaves 1 m strips between the filled building masses and a room wall (its raster keeps 0.5 m
    around every reserved edge) and a few 0.4-1.2 m seams beside covers. A 1 m strip is wide enough for a player
    capsule to enter but too narrow to be a street: a hiding slit with light and bullets passing through.  Grow the
    derived (filled) masses across every such gap that is not part of a street, a room or a basin."""
    free = [o["r"] for o in P.ops if o["op"] in ("free", "sunken")] + [o["r"] for o in P.ops if o["op"] == "room"]
    free += [o["r"] for o in P.ops if o["op"] == "slab" and o.get("solid")] if False else []
    grown = 0
    changed = True
    while changed:
        changed = False
        rects = solid_rects(P)
        for a in rects:
            oa = a[4]
            if a[5] != "block" or not oa.get("derived"):
                continue
            for b in rects:
                if b is a or (b[5] == "cover" and False):
                    continue
                for ax in (0, 1):
                    oax = 1 - ax
                    lo = max(a[oax], b[oax])
                    hi = min(a[oax + 2], b[oax + 2])
                    if hi - lo < minlen:
                        continue
                    if b[ax] >= a[ax + 2] - 1e-6:          # b lies on the + side of a
                        g = b[ax] - a[ax + 2]
                        side = 2
                    elif b[ax + 2] <= a[ax] + 1e-6:        # b lies on the - side
                        g = a[ax] - b[ax + 2]
                        side = 0
                    else:
                        continue
                    if not (0.02 < g <= maxgap):
                        continue
                    # the gap rectangle
                    if side == 2:
                        g0, g1 = a[ax + 2], b[ax]
                    else:
                        g0, g1 = b[ax + 2], a[ax]
                    gr = [g0, lo, g1, hi] if ax == 0 else [lo, g0, hi, g1]
                    if any(min(gr[2], f[2]) - max(gr[0], f[0]) > 0.15 and min(gr[3], f[3]) - max(gr[1], f[1]) > 0.15 for f in free):
                        continue
                    if any(c is not a and c is not b and c[0] < gr[2] - 1e-6 and c[2] > gr[0] + 1e-6 and c[1] < gr[3] - 1e-6 and c[3] > gr[1] + 1e-6 for c in rects):
                        continue
                    r = oa["r"]
                    if ax == 0:
                        if side == 2:
                            r[2] = round(b[0], 2)
                        else:
                            r[0] = round(b[2], 2)
                    else:
                        if side == 2:
                            r[3] = round(b[1], 2)
                        else:
                            r[1] = round(b[3], 2)
                    grown += 1
                    changed = True
                    break
                if changed:
                    break
            if changed:
                break
    return grown


def build():
    P = Plan("tideline", ex=72, ez=44, seed=21)
    P.outline([(0, -39), (-54, -39), (-62, -34), (-70, -24), (-70, 24), (-62, 34), (-54, 40), (0, 40)],
              rails=[(-60, -41, 0, -37), (-64, -37, -53, -32), (-72, -30, -62, -22), (-72, -22, -68, 22)])   # open sea sides

    # ---------------------------------------------------------------- spawn dock and its jogged exits
    P.free(-69, -9, -59, 9)                    # spawn dock
    P.free(-69, -26, -65, -9)                  # north exit (west rail side)
    P.free(-69, -31, -56, -26)                 # north-west corner, jogs east to the quay
    P.free(-63, 9, -59, 22)                    # south exit (east side of the dock)
    P.free(-63, 22, -50, 27)                   # home berth (stabilizer), joins the channel head
    P.free(-59, -3, -52, 3)                    # forecourt to the bay

    # ---------------------------------------------------------------- vault bay with mezzanine
    P.room(-52, -10, -36, 10, 8.0, doors={"w": [[0, 5]], "e": [[-3, 5]], "n": [[4, 4]], "s": [[-4, 4]]},
           mat="wall_a", roof="roof", lights=[[-44, 6.6, 0]])
    P.cover("box", -49.9, 6.2, (2.6, 2.6, 2.6), 0, "cover_crate")              # cargo inside the bay (flush with the west wall)
    P.cover("box", -41, 7.9, (1.6, 1.3, 2.6), 0, "cover_crate_b")                # flush with the south wall
    P.column(-44, 3.6, 6.0, 0.35, mat="steel")
    P.platform([-51.4, -9.4, -36.6, -6.0], 4.0, mat="steel", solid=False, thick=0.4)      # mezzanine along the north wall (deck runs into both side walls: no 0.6 m seams)
    P.ladder((-44, 0, -4.8), 4.0, (0, 1), "V1", "V1")
    P.cover("box", -48, -8.7, (2.2, 1.0, 1.0), 0, "cover_crate", y0=4.0)
    P.cover("box", -40, -8.1, (1.0, 1.0, 2.2), 0, "cover_crate", y0=4.0)

    # ---------------------------------------------------------------- yard street between bay and hall
    P.free(-36, -6, -14, 6)
    P.block(-32.5, -6, -28.5, -2.4, 5.2, "cover_crate_b")                       # stack island pinches the street (north)
    P.block(-25, 2.4, -19, 6, 5.2, "cover_crate")                               # second island (south): S-bend
    P.cover("box", -22, -4.7, (3.0, 1.3, 2.6), 0, "cover_crate")
    P.cover("box", -30, 4.7, (2.6, 2.6, 2.6), 0, "cover_crate_b")
    P.cover("box", -17, 0.5, (2.0, 1.3, 2.0), 0, "cover_crate")

    # ---------------------------------------------------------------- exchange hall (14 m, galleries at y 5)
    P.room(-14, -17, 14, 17, 14.0, doors={"w": [[0, 4]], "e": [[0, 4]], "n": [[0, 6]], "s": [[0, 6]]},
           mat="wall_b", roof="roof", mirror=False, t=1.0, lights=[[-7, 11.5, 0], [7, 11.5, 0], [0, 11.5, -10], [0, 11.5, 10]])
    P.platform([-13, -16.4, 13, -12.0], TY, mat="steel", solid=False, thick=0.45, mirror=False)    # north gallery
    P.platform([-13, 12.0, 13, 16.4], TY, mat="steel", solid=False, thick=0.45, mirror=False)      # south gallery
    P.stairs((-11.9, 0, -3.0), (-11.9, TY, -12.0), 3.0, mirror=False)                               # carrier way up (4 flights)
    P.stairs((11.9, 0, -3.0), (11.9, TY, -12.0), 3.0, mirror=False)
    P.stairs((-11.9, 0, 3.0), (-11.9, TY, 12.0), 3.0, mirror=False)
    P.stairs((11.9, 0, 3.0), (11.9, TY, 12.0), 3.0, mirror=False)
    P.ladder((-5, 0, -10.8), TY, (0, 1), "H1", "H1", mirror=False)
    P.ladder((5, 0, -10.8), TY, (0, 1), "H2", "H2", mirror=False)
    P.ladder((-5, 0, 10.8), TY, (0, -1), "H3", "H3", mirror=False)
    P.ladder((5, 0, 10.8), TY, (0, -1), "H4", "H4", mirror=False)
    for gx in (-8, 8):
        P.column(gx, -7, 13.0, 0.5, mat="steel", mirror=False)
        P.column(gx, 7, 13.0, 0.5, mat="steel", mirror=False)
    P.cover("box", 0, 0, (4.6, 2.6, 2.6), 0, "cover_crate_b", mirror=False)              # centre stack blocks the door-to-door line
    P.cover("box", -5, -4.5, (2.6, 1.3, 2.6), 0, "cover_crate", mirror=False)
    P.cover("box", 5, 4.5, (2.6, 1.3, 2.6), 0, "cover_crate", mirror=False)
    P.cover("box", 4.5, -6.5, (2.6, 2.6, 4.6), 0, "cover_crate", mirror=False)
    P.cover("box", -4.5, 6.5, (2.6, 2.6, 4.6), 0, "cover_crate_b", mirror=False)
    P.cover("box", -9.5, 0, (1.2, 2.6, 2.4), 0, "cover_crate", mirror=False)
    P.cover("box", 9.5, 0, (1.2, 2.6, 2.4), 0, "cover_crate_b", mirror=False)
    P.cover("box", -9, -15.55, (2.2, 1.0, 0.9), 0, "cover_crate", y0=TY, mirror=False)             # gallery cover
    P.cover("box", 8, -15.55, (2.2, 1.0, 0.9), 0, "cover_crate", y0=TY, mirror=False)
    P.cover("box", -8, 15.55, (2.2, 1.0, 0.9), 0, "cover_crate", y0=TY, mirror=False)
    P.cover("box", 9, 15.55, (2.2, 1.0, 0.9), 0, "cover_crate", y0=TY, mirror=False)
    P.zip((-11, TY, -14.2), (11, TY, 14.2), "HALL A", "HALL A", mirror=False)
    P.zip((11, TY, -14.2), (-11, TY, 14.2), "HALL B", "HALL B", mirror=False)

    # ---------------------------------------------------------------- north: quay lane, gantry, warehouse passage
    P.free(-42, -30, -38, -10)                 # bay north-door lane
    P.free(-60, -38, -14, -30)                 # quay (8 m deep, open to the sea on the north rail)
    P.free(-9, -38, 9, -30)                    # central quay
    P.free(-3, -30, 3, -17)                    # hall north lane, straight to the hall's north door
    P.room(-34, -26, -22, -9, 7.0, doors={"n": [[0, 4]], "s": [[0, 4]]}, mat="wall_c", roof="roof", lights=[[-28, 5.6, -17]])   # warehouse passage
    P.free(-30, -30, -26, -26)                 # quay -> warehouse north door
    P.free(-30, -9, -26, -6)                   # warehouse south door -> yard
    P.cover("box", -29.8, -22.2, (1.6, 2.2, 6.0), 0, "cover_crate_b")              # racks: indoor aisles
    P.cover("box", -25.8, -15, (1.6, 2.2, 6.0), 0, "cover_crate")
    # customs fences across the quay (4.4 m, below the gantry): every 12 m one has to turn through a 3.4 m gap
    for fx, gap_north in ((-45.0, True), (-33.0, False), (-21.0, True)):
        if gap_north:
            P.wall((fx, -30.0), (fx, -34.4), 4.55, 0.6, "wall_a")
        else:
            P.wall((fx, -38.0), (fx, -33.6), 4.55, 0.6, "wall_a")
    P.cover("box", -55.5, -31.2, (3.0, 1.3, 2.4), 0, "cover_crate_b")
    P.cover("box", -39, -36.7, (2.6, 1.3, 2.6), 0, "cover_crate")
    P.cover("box", -27, -31.3, (2.6, 1.3, 2.6), 0, "cover_crate_b")
    P.cover("box", -17.5, -36.9, (2.6, 1.3, 2.2), 0, "cover_crate")
    P.column(-36.0, -34.0, 4.6, 0.55, mat="steel")                                  # gantry legs (reach the deck)
    P.column(-24.5, -37.4, 4.6, 0.55, mat="steel")
    P.cover("box", -6, -33.5, (2.6, 1.3, 2.6), 0, "cover_crate")
    P.cover("box", 0, -35.0, (2.6, 1.3, 2.6), 0, "cover_crate_b", mirror=False)
    # gantry over the quay's north half (y 5): ladders for everyone else, stairs at the west end for carriers
    P.platform([-49, -38.0, -14, -33.4], TY, mat="steel", solid=False, thick=0.45)
    P.platform([-14, -38.0, 14, -33.4], TY, mat="steel", solid=False, thick=0.45, mirror=False)
    P.wall((-49, -37.75), (-14, -37.75), 1.1, 0.5, "steel", y0=TY)
    P.stairs((-59, 0, -35.5), (-49, TY, -35.5), 3.0)
    P.ladder((-39.5, 0, -32.2), TY, (0, 1), "Q1", "Q1")
    P.ladder((-17.5, 0, -32.2), TY, (0, 1), "Q2", "Q2")
    P.cover("box", -43, -37.05, (2.2, 1.0, 0.9), 0, "cover_crate", y0=TY)
    P.cover("box", -28, -37.05, (2.2, 1.0, 0.9), 0, "cover_crate", y0=TY)
    P.zip((-47, TY, -35.4), (-18, TY, -35.4), "QUAY W", "QUAY E")

    # ---------------------------------------------------------------- south: lanes, yard, channel
    P.free(-50, 10, -46, 24)                   # bay south-door lane
    P.free(-50, 24, -44, 27)                   # channel head (stairs down)
    P.free(-46, 17, -26, 21)                   # lane east
    P.free(-26, 12, -18, 21)                   # south yard
    P.free(-24, 6, -20, 12)                    # yard -> south yard link
    P.free(-22, 21, -18, 27)                   # head of the mid-channel ladder C1 (its top used to land inside a building mass)
    P.free(-8, 17.5, 8, 24)                    # hall south plaza
    P.block(-40, 17, -37, 19.5, 5.2, "cover_crate")                             # lane pinch
    P.cover("box", -30, 17.9, (2.6, 2.6, 1.8), 0, "cover_crate_b")
    P.cover("box", -22, 15, (2.6, 1.3, 2.6), 0, "cover_crate")
    P.cover("box", -4, 20.5, (2.6, 1.3, 2.6), 0, "cover_crate")
    P.sunken(-52, 27, 52, 35, CH, mirror=False)                              # loading channel (weirs make S-bends)
    P.stairs((-48, CH, 32.5), (-48, 0, 27), 4.0)                              # carrier entry/exit stairs at the ends (low end first: MapKit.stairs builds the treads upward from it)
    P.ladder((-20, CH, 28.2), 0.0, (0, 1), "C1", "C1")                        # mid access: ladders only (no carrier shortcut)
    P.block(-40, 27, -39, 31, 4.6, "wall_c", y0=CH)                           # weirs (2.2 m above the lane: nobody sees over them from the stairs): S-bend gaps alternate side
    P.block(-27, 31, -26, 35, 4.6, "wall_c", y0=CH)
    P.block(-14, 27, -13, 31, 4.6, "wall_c", y0=CH)
    P.block(-3, 31, 3, 35, 4.6, "wall_c", y0=CH, mirror=False)
    P.cover("box", -30.5, 33.2, (2.6, 1.3, 1.2), 0, "cover_crate", y0=CH)
    P.cover("box", -20, 33, (2.6, 1.3, 1.2), 0, "cover_crate", y0=CH)

    # ---------------------------------------------------------------- spawn dock cover
    P.cover("box", -66.2, 3.0, (1.2, 2.6, 4.0), 0, "cover_crate")
    P.cover("box", -66.2, -3.4, (1.2, 1.3, 2.6), 0, "cover_crate_b")
    P.cover("box", -65.9, -17, (1.8, 2.6, 2.6), 0, "cover_crate_b")
    P.cover("box", -62.1, 12.0, (1.8, 2.6, 3.0), 0, "cover_crate")
    P.cover("box", -61, -30.2, (2.6, 1.3, 1.6), 0, "cover_crate")

    # ---------------------------------------------------------------- temporal barricades (restorable cover)
    P.prop(-27, 1.5, (2.6, 1.6, 0.5), 90, color="5A6AA0")                      # yard street
    P.prop(-22, 17.5, (2.6, 1.6, 0.5), 90, color="5A6AA0")                     # south yard
    P.prop(-50, -31.2, (2.6, 1.6, 0.5), 90, color="5A6AA0")                    # quay west end
    P.prop(-60.1, 15.5, (2.2, 1.6, 0.5), 0, color="5A6AA0")                      # south exit
    P.prop(-6.5, -9.0, (2.6, 1.6, 0.5), 0, color="5A6AA0", mirror=False)       # hall floor, north side
    P.prop(6.5, 9.0, (2.6, 1.6, 0.5), 0, color="5A6AA0", mirror=False)         # hall floor, south side

    # ---------------------------------------------------------------- spawns / objectives / modes
    P.spawn_west([(-63, -6, -90), (-63, 6, -90), (-61, -2.5, -90), (-61, 2.5, -90)])
    P.set_layout([-44, 0, 0], [44, 0, 0], [-57, 0, 24.5], [57, 0, 24.5], [[-34, CH, 30], [34, CH, 30]], 8.0, 1.6)
    P.ffa([[-64, -6, -90], [-64, 6, -90], [-56, 24.5, 0], [-34, 30, 0], [-35.5, -35.5, 0], [-2.5, -31.5, 180], [0, 22, 180], [-30, 0, 90],
           [64, -6, 90], [64, 6, 90], [56, 24.5, 0], [34, 30, 0], [35.5, -35.5, 0], [2.5, -31.5, 180], [30, 0, -90], [-22, 18.5, 0]])
    P.shards([[-4.6, 0.5, 1.8], [-34, CH + 0.5, 30], [34, CH + 0.5, 30], [-37, TY + 0.5, -35.5], [37, TY + 0.5, -35.5], [0.5, 0.5, -31.5], [-3, TY + 0.5, -14.4], [3, TY + 0.5, 14.4]])
    P.beacons([[-4.6, 0.5, 1.8], [0.5, 0.5, -31.5], [-34, CH, 30], [34, CH, 30]])
    P.solidify(h=(7.0, 11.0), maxdim=14.0, mats=("wall_a", "wall_b", "wall_c"))
    P.slivers = P.fill_slivers()
    P.sealed = seal_slits(P)
    return P


if __name__ == "__main__":
    P = build()
    if "gen" in sys.argv:
        print("emitted", P.emit_gd("src/maps/plans/tideline_plan.gd"), "ops")
        P.build()
        os.makedirs("assets/ui", exist_ok=True)
        P.render_preview("assets/ui/map_tideline_exchange.png")
        sys.exit(0)
    spawn = {"spawn_W": (-62, 0), "vault_W": (-44, 0), "stab_W": (-57, 24.5), "hall": (0, 0), "channelW": (-34, 30)}
    report(P, spawn_xz=spawn, heat_png="build/maps/tideline_heat.png", plan_png="build/maps/tideline_plan.png", sight_layers=(0.0, 5.0, -2.4))
