"""VECTOR FOUNDRY - street plan (west half authored, east half mirrored).

Ring-and-spoke foundry.  A roofed REACTOR (r 15) sits inside a RING STREET (r 15.7..21.2) whose outer wall opens only on the
four axes; the reactor's doors face the diagonals, so no street runs straight through the middle.  A roofed SERVICE TUNNEL
(floor y -3.2) runs under the south block and holds both Stability Fields behind staggered bulkheads.  A WATCHTOWER (y 6)
north of the ring is joined to two landing decks by narrow walkways; launch pads throw non-carriers onto the decks, and
ladders climb the tower.  Gates link the two yards on each home side (they refuse the Core).

  direct : enemy bay -> west/east spoke -> ring (south arc) -> spoke -> home bay -> south lane -> berth
  tunnel : enemy bay south door -> lane -> pit stairs -> tunnel (bulkheads, fields) -> pit stairs -> lane -> berth
  north  : bay north door -> north yard -> north street -> ring north opening / tower plaza
  upper  : landing decks + walkways (y 6) + tower: stairs for carriers, launch pads and ladders for the rest
"""
import math
import os
import sys
sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0])
from proto import Plan, report

TW = 6.0      # tower / walkway height
TUN = -3.2    # service tunnel floor


def sectors(r0, r1, n, rot=0.0):
    out = []
    for i in range(n):
        a0 = math.radians(rot + 360.0 * i / n)
        a1 = math.radians(rot + 360.0 * (i + 1) / n)
        out.append([(r0 * math.cos(a0), r0 * math.sin(a0)), (r1 * math.cos(a0), r1 * math.sin(a0)),
                    (r1 * math.cos(a1), r1 * math.sin(a1)), (r0 * math.cos(a1), r0 * math.sin(a1))])
    return out


def ngon(r, n, rot=0.0):
    return [(r * math.cos(math.radians(rot + 360.0 * k / n)), r * math.sin(math.radians(rot + 360.0 * k / n))) for k in range(n)]


def build():
    P = Plan("foundry", ex=72, ez=44, seed=31)
    P.outline([(0, -41.5), (-50, -41.5), (-60, -37), (-70, -26), (-70, 26), (-60, 36), (-50, 40), (0, 40)])

    # ---------------------------------------------------------------- ring street, ring wall, reactor
    for poly in sectors(14.5, 21.9, 32):          # overlaps both walls so every opening stays unfilled
        P.free_poly(poly, mirror=False)
    ringv = ngon(22.0, 32, -5.625)
    for k in range(32):
        if k % 8 == 0:                          # openings on the four axes
            continue
        P.wall(ringv[k], ringv[(k + 1) % 32], 9.0, 1.2, "wall_c", mirror=False)
    rv = ngon(14.5, 24, -7.5)
    for k in range(24):
        if k % 6 == 3:                          # reactor doors on the diagonals
            continue
        a, b = list(rv[k]), list(rv[(k + 1) % 24])
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        ux, uz = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
        if k % 6 == 4:                          # jamb on the door's near side: pull the wall back to widen the opening
            a = [a[0] + ux * 0.8, a[1] + uz * 0.8]
        if k % 6 == 2:
            b = [b[0] - ux * 0.8, b[1] - uz * 0.8]
        P.wall(a, b, 11.0, 1.0, "wall_b", mirror=False)
    P.platform([(x, z) for x, z in ngon(15.2, 24, -7.5)], 11.5, mat="roof", solid=False, thick=0.5, walk=False, mirror=False, roof=True)
    P.free_poly(ngon(14.5, 24, -7.5), mirror=False)                          # reactor interior
    P.cover("cyl", 0, 0, (2.3, 9.0), mat="steel", mirror=False)              # reactor core
    for a in (0, 90, 180, 270):
        x, z = 8.8 * math.cos(math.radians(a)), 8.8 * math.sin(math.radians(a))
        yaw = math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a))))
        P.cover("box", round(x, 2), round(z, 2), (3.4, 1.2, 1.2), round(yaw, 1), "cover_machine", mirror=False)
    for a in (22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5):
        x, z = 11.0 * math.cos(math.radians(a)), 11.0 * math.sin(math.radians(a))
        P.column(round(x, 2), round(z, 2), 10.0, 0.45, mat="steel", mirror=False)
    for a in (22.5, 112.5, 202.5, 292.5):                                      # ring street cover hugs the outer wall (2.7 m lane stays free)
        x, z = 20.3 * math.cos(math.radians(a)), 20.3 * math.sin(math.radians(a))
        yaw = math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a))))
        P.cover("box", round(x, 2), round(z, 2), (3.0, 1.3, 1.2), round(yaw, 1), "cover_machine", mirror=False)
    for a in (67.5, 157.5, 247.5, 337.5):                                      # columns hug the reactor wall
        x, z = 16.0 * math.cos(math.radians(a)), 16.0 * math.sin(math.radians(a))
        P.column(round(x, 2), round(z, 2), 6.0, 0.5, mat="steel", mirror=False)

    # ---------------------------------------------------------------- spawn yard and exits
    P.free(-69, -9, -59, 9)                    # spawn yard
    P.free(-65, -24, -61, -9)                  # north exit (east side of the yard)
    P.free(-69, 9, -65, 22)                    # south exit (west side)
    P.free(-69, 22, -55, 26)                   # jog east
    P.free(-59, -3, -56, 3)                    # forecourt to the bay

    # ---------------------------------------------------------------- vault bay (assembly chamber)
    P.room(-56, -9, -38, 9, 8.0, doors={"w": [[0, 5]], "e": [[0, 5]], "n": [[4, 4]], "s": [[-4, 4]]}, mat="wall_a", roof="roof",
           lights=[[-47, 6.6, 0]])
    P.cover("box", -43.5, 6.0, (2.6, 2.4, 2.6), 0, "cover_machine")
    P.cover("box", -51.5, -6.0, (2.6, 1.3, 2.6), 0, "cover_machine")
    P.cover("box", -39.6, 5.4, (1.6, 1.3, 2.4), 0, "cover_machine")
    P.cover("box", -39.4, -5.0, (1.6, 2.4, 2.4), 0, "cover_machine")
    P.column(-47, 4.0, 6.5, 0.35, mat="steel")
    P.column(-47, -4.0, 6.5, 0.35, mat="steel")
    P.block(-52.6, -1.0, -52.0, 1.0, 2.6, "cover_machine")                      # blast screen three metres inside the west door
    P.free(-38, -2.5, -21.5, 2.5)              # west spoke to the ring
    P.cover("box", -30, -1.4, (1.4, 1.2, 1.4), 0, "cover_machine")

    # ---------------------------------------------------------------- north: yard, street, tower plaza, decks
    P.free(-45, -24, -41, -9)                  # bay north-door lane
    P.free(-64, -33, -38, -24)                 # north-west yard
    P.free(-38, -40, -2.5, -31)                # north street (walkway above its north half)
    P.free(-8, -40, 8, -31)                    # tower plaza (T-junction behind the generator house)
    P.free(-2.5, -31, 2.5, -22)                # north spoke
    P.block(-63, -33, -58, -29, 4.0, "cover_machine")                           # press
    P.block(-49, -32.5, -46, -29.5, 3.0, "cover_machine")                       # furnace stack
    P.cover("box", -61, -17, (2.6, 2.6, 2.6), 0, "cover_machine")
    P.block(-27, -40, -23, -33.6, 4.5, "cover_machine")                         # pinch the north street (gap south)
    P.cover("box", -15, -34.5, (2.6, 1.3, 2.6), 0, "cover_machine")
    P.cover("box", -34, -32.5, (2.6, 1.3, 2.6), 0, "cover_machine")
    # landing deck + walkway + tower
    P.platform([-58, -40, -46, -34], TW, mat="steel", solid=False, thick=0.5)
    P.platform([(-46, -39.2), (-3.5, -39.2), (-3.5, -35.6), (-46, -35.6)], TW, mat="steel", solid=False, thick=0.4)
    P.block(-4, -40, 4, -31, 5.6, "wall_b", mirror=False)                       # generator house carries the tower deck
    P.platform([(x, z - 34.0) for x, z in ngon(4.8, 8, 22.5)], TW, mat="steel", solid=False, thick=0.5, mirror=False)
    P.block(-1.7, -38.8, 1.7, -33.2, 3.4, "wall_b", y0=TW, mirror=False)               # control cabin: no straight line along both walkways
    P.wall((-46, -39.0), (-3.5, -39.0), 1.1, 0.25, "hazard", y0=TW)
    P.column(-24, -36.4, TW - 0.4, 0.3, mat="steel")
    P.stairs((-54, 0, -25), (-54, TW, -34), 3.6)                           # carriers' way up (north-west yard)
    P.ladder((-5.4, 0, -34.0), TW, (-1, 0), "T1", "T1", mirror=False)           # tower ladders, west and east faces
    P.ladder((5.4, 0, -34.0), TW, (1, 0), "T2", "T2", mirror=False)
    P.sling((-39.5, 0, -28), (-50, TW, -37), 1.3, "N1", "N1")                  # launch pad: lane -> landing deck
    P.cover("box", -53, -38.1, (2.2, 1.0, 0.9), 0, "cover_machine", y0=TW)
    P.cover("box", -34, -38.0, (2.2, 1.0, 0.9), 0, "cover_machine", y0=TW)
    P.cover("box", -14, -38.0, (2.2, 1.0, 0.9), 0, "cover_machine", y0=TW)

    # ---------------------------------------------------------------- south: lanes, berth, pits and the service tunnel
    P.free(-53, 9, -49, 22)                    # bay south-door lane
    P.free(-62, 14, -49, 22)                   # home berth (stabilizer)
    P.free(-49, 21, -40, 26)                   # lane east to the pit
    P.free(-44, 26, -34, 27)                   # pit head
    P.free(-26, 12, -6, 17)                    # south-west yard (ring south opening side)
    P.free(-2.5, 21, 2.5, 26)                  # south spoke
    P.free(-14, 24, 14, 27)                    # south street along the tunnel block
    P.block(-30, 16, -26, 22.5, 4.0, "cover_machine")
    P.cover("box", -18, 21, (3.0, 1.3, 2.6), 0, "cover_machine")
    P.cover("box", -9, 25.5, (2.6, 1.3, 1.2), 0, "cover_machine")
    P.sunken(-44, 27, 44, 35, TUN, mirror=False)                              # service tunnel + pits
    P.block(-34, 27, 34, 35, 9.5, "wall_c", y0=-0.5, mirror=False)             # roof and the south block above it
    P.stairs((-41, 0, 27), (-41, TUN, 33), 4.0)                                # carrier entry/exit at the pits
    P.block(-30, 27, -29, 31, 2.6, "wall_c", y0=TUN)                           # bulkheads: gaps alternate sides
    P.block(-22, 31, -21, 35, 2.6, "wall_c", y0=TUN)
    P.block(-14, 27, -13, 31, 2.6, "wall_c", y0=TUN)
    P.block(-3, 31, 3, 35, 2.6, "wall_c", y0=TUN, mirror=False)
    for gx in (-26, -10, 10, 26):
        P.light(gx, TUN + 2.2, 31, "FFB070", 1.1, 8.0, mirror=False)

    # ---------------------------------------------------------------- gates: home-side rotations (refuse the Core)
    P.gate((-62.5, 0, -28.5), -90, (-43.0, 0, 23.5), 90, "I")
    P.gate((62.5, 0, -28.5), 90, (43.0, 0, 23.5), -90, "II")

    # ---------------------------------------------------------------- spawn yard cover
    P.cover("box", -66.2, 3.4, (1.2, 2.6, 4.0), 0, "cover_machine")
    P.cover("box", -66.2, -3.4, (1.2, 1.3, 2.6), 0, "cover_machine")
    P.cover("box", -62, 16.5, (2.6, 1.3, 2.6), 0, "cover_machine")
    P.cover("box", -63, -20, (2.6, 1.3, 2.6), 0, "cover_machine")

    # ---------------------------------------------------------------- temporal barricades (restorable cover)
    P.prop(-30, 4.5, (2.6, 1.6, 0.5), 90, color="E2B07A")                      # west spoke
    P.prop(-43, -16, (3.0, 1.6, 0.5), 0, color="E2B07A")                       # north lane
    P.prop(-12, -34, (3.0, 1.6, 0.5), 0, color="E2B07A")                       # north street
    P.prop(-45, 23.5, (3.0, 1.6, 0.5), 0, color="E2B07A")                      # pit lane
    for a in (45, 225):                                                         # ring street barricades hug the outer wall
        px, pz = 20.3 * math.cos(math.radians(a)), 20.3 * math.sin(math.radians(a))
        pyaw = math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a))))
        P.prop(round(px, 2), round(pz, 2), (2.6, 1.6, 0.5), round(pyaw, 1), color="E2B07A", mirror=False)

    # ---------------------------------------------------------------- spawns / objectives / modes
    P.spawn_west([(-64, -7, -90), (-64, 7, -90), (-61.5, -3, -90), (-61.5, 3, -90)])
    P.set_layout([-47, 0, 0], [47, 0, 0], [-58, 0, 18], [58, 0, 18], [[-26, TUN, 30], [26, TUN, 30]], 8.0, 1.6)
    P.ffa([[-64, -7.5, -90], [-64, 7.5, -90], [-56, 18, 0], [-26, 30, 0], [-31, -35, 0], [0, -26, 0], [0, 23, 180], [-30, 0, 90],
           [64, -7.5, 90], [64, 7.5, 90], [56, 18, 0], [26, 30, 0], [31, -35, 0], [-13.1, 13.1, 0], [30, 0, -90], [13.1, -13.1, 180]])
    P.shards([[4.5, 0.5, 4.5], [-26, TUN + 0.5, 30], [26, TUN + 0.5, 30], [-30, TW + 0.5, -36.6], [30, TW + 0.5, -36.6], [0, 0.5, -26], [0, 0.5, 23], [0, TW + 0.5, -31]])
    P.beacons([[4.5, 0.5, 4.5], [0, TW, -31], [-26, TUN, 30], [26, TUN, 30]])
    P.solidify(h=(7.0, 11.0), maxdim=14.0, mats=("wall_a", "wall_b", "wall_c"))
    P.slivers = P.fill_slivers()
    return P


if __name__ == "__main__":
    P = build()
    if "gen" in sys.argv:
        print("emitted", P.emit_gd("src/maps/plans/foundry_plan.gd"), "ops")
        P.build()
        os.makedirs("assets/ui", exist_ok=True)
        P.render_preview("assets/ui/map_vector_foundry.png")
        sys.exit(0)
    spawn = {"spawn_W": (-64, 0), "vault_W": (-47, 0), "stab_W": (-58, 18), "ring": (18.5, 0), "tunnelW": (-26, 31), "tower": (0, -36.5)}
    report(P, spawn_xz=spawn, heat_png="build/maps/foundry_heat.png", plan_png="build/maps/foundry_plan.png", sight_layers=(0.0, 6.0, -3.2))
