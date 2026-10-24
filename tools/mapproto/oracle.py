"""ORACLE GARDENS - street plan (west half authored, east half mirrored).

Macro structure (carry route from the enemy vault at the far east to the home stabilizer in the north-west):
  direct   : enemy temple -> plaza -> Oracle Court (monument ring) -> plaza -> home temple -> north alley -> yard
  garden   : enemy temple north alley -> terrace stairs -> terrace B (field) -> S-bend arcade -> central terrace ->
             S-bend arcade -> terrace A (field) -> stairs -> reliquary yard.  Carriers can only enter/leave the
             terraces at the far ends; ladders give everybody else mid-route access (the Core is too heavy to climb).
  south    : temples' south alleys -> south lanes -> chapels -> sunken basin (flank / rotation).
  gates    : home-side rotation pairs (gate court <-> reliquary yard); gates refuse the Core.
"""
import math
import os
import sys
sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0])
from proto import Plan, report

TR = 3.0   # terrace height


def build():
    P = Plan("oracle", ex=72, ez=44, seed=11)
    P.outline([(0, -40), (-52, -40), (-60, -36), (-70, -26), (-70, 26), (-60, 36), (-52, 40), (0, 40)])

    # ---------------------------------------------------------------- spawn court and its jogged exits
    P.free(-68, -8, -58, 8)                    # spawn court
    P.free(-67, -20, -63, -8)                  # north exit (west side of the court)
    P.free(-67, -24, -56, -20)                 # jog east
    P.free(-62, 8, -58, 20)                    # south exit (east side: never lines up with the north exit)
    P.free(-62, 20, -48, 24)                   # jog east

    # ---------------------------------------------------------------- reliquary yard (home stabilizer)
    P.free(-62, -38, -42, -24)                 # yard: stabilizer, terrace stairs on its east side
    P.free(-50, -24, -46, -9)                  # north alley from the temple north gate

    # ---------------------------------------------------------------- vault temple
    P.room(-52, -9, -34, 9, 7.0, doors={"n": [[-5, 4]], "s": [[5, 4]], "e": [[0, 5]]}, mat="wall_a", roof="roof",
           lights=[[-43, 5.4, 0]])
    P.wall((-49, -3), (-49, 3), 3.0, 0.8, "wall_b")                         # cradle screen
    P.wall((-41, -6), (-37, -6), 3.0, 0.8, "wall_b")                        # screens by the gates
    P.wall((-41, 6), (-37, 6), 3.0, 0.8, "wall_b")
    P.free(-40, 9, -36, 24)                    # south alley

    # ---------------------------------------------------------------- mid: gate approach, plaza, court
    P.free(-34, -3, -28, 3)
    P.free(-28, -7, -20, 7)                    # cistern plaza with a well monument
    P.block(-26, -2, -22, 2, 5.0, "wall_c")
    P.free(-20, -3, -13, 3)
    P.free_poly([(-13, -5.4), (-5.4, -13), (5.4, -13), (13, -5.4), (13, 5.4), (5.4, 13), (-5.4, 13), (-13, 5.4)])
    for a, b in (((-13, -5.4), (-5.4, -13)), ((5.4, -13), (13, -5.4)), ((13, 5.4), (5.4, 13)), ((-5.4, 13), (-13, 5.4))):
        P.wall(a, b, 6.0, 1.2, "wall_a", mirror=False)               # smooth diagonal court walls
    P.poly_block([(-3.2, -7.7), (3.2, -7.7), (7.7, -3.2), (7.7, 3.2), (3.2, 7.7), (-3.2, 7.7), (-7.7, 3.2), (-7.7, -3.2)], 6.0, "wall_c", mirror=False)  # oracle plinth
    P.free(-28, -24, -24, -7)                  # cistern alley north (ladder to terrace A)
    P.free(-28, 7, -24, 20)                    # cistern alley south
    P.free(-4, -24, 4, -13)                    # court north corridor (ladder to the central terrace)
    P.free(-4, 13, 4, 18)                      # court south corridor

    # ---------------------------------------------------------------- terraces (raised, solid)
    P.platform([-42, -38, -6, -24], TR)        # terrace A + arcade A (one raised slab)
    P.platform([-6, -38, 6, -24], TR, mirror=False)      # central terrace
    P.room(-14, -38, -6, -24, 4.0, doors={"w": [[-4, 4]], "e": [[4, 4]]}, mat="wall_a", roof="roof", floor=TR, lights=[[-10, 6.4, -31]])  # S-bend arcade
    P.block(-35.6, -35.6, -32.4, -32.4, 4.5, "wall_c", y0=TR)    # shrine beside terrace A's field centre
    P.block(-4, -37, 4, -33, 5.0, "wall_c", y0=TR, mirror=False)    # central terrace screen
    P.stairs((-48, 0, -31), (-42, TR, -31), 4.0)           # yard -> terrace A (the only carrier access on this side)
    P.ladder((-26, 0, -22.8), TR, (0, 1), "CA")            # cistern alley ladder (non-carriers)
    P.ladder((0, 0, -22.8), TR, (0, 1), "CT", mirror=False)  # court north ladder

    # ---------------------------------------------------------------- south: gate court, lanes, chapel, basin
    P.free(-56, 24, -44, 37)                   # gate court
    P.free(-44, 24, -34, 32)                   # south lane 1
    P.room(-34, 20, -22, 34, 6.0, doors={"w": [[1, 4]], "n": [[2, 4]], "e": [[-2, 4]]}, mat="wall_b", roof="roof", lights=[[-28, 4.6, 27]])  # chapel
    P.wall((-30, 26), (-30, 29), 2.6, 0.8, "wall_b")
    P.free(-22, 23, -12, 29)                   # chapel exit lane to the basin
    P.block(-19, 23, -16, 26, 3.0, "wall_c")   # lane shrine
    P.sunken(-12, 18, 12, 34, -1.6, mirror=False)
    P.block(-3, 27, 3, 33, 5.6, "wall_c", y0=-1.6, mirror=False)    # basin pavilion
    P.stairs((0, -1.6, 24), (0, 0, 18), 6.0, mirror=False)          # basin -> court (low end first, or the visible steps collapse to 5 cm plates)
    P.stairs((-6, -1.6, 26), (-12, 0, 26), 4.0)                     # basin -> chapel lane

    # ---------------------------------------------------------------- phase gates (home-side rotation, refuse the Core)
    P.gate((-50, 0, 34.5), 0, (-52, 0, -35.5), 180, "I")
    P.gate((50, 0, 34.5), 0, (52, 0, -35.5), 180, "II")

    # ---------------------------------------------------------------- cover (low = shoot-over, tall = sight blocker)
    # spawn court
    P.cover("box", -61, -4.5, (3.0, 1.1, 1.0), 0, "cover_stone")
    P.cover("box", -61, 4.5, (3.0, 1.1, 1.0), 0, "cover_stone")
    P.cover("cyl", -64.5, 0, (0.9, 2.4), mat="cover_dark")
    # reliquary yard
    P.cover("box", -56.0, -35.6, (3.0, 1.2, 1.2), 0, "cover_glaze")          # west of the phase gate (-52,-35.5), clear of the diagonal corner wall
    P.cover("box", -58, -27, (1.2, 1.2, 3.4), 0, "cover_stone")
    P.cover("cyl", -49, -28, (0.9, 1.3), mat="cover_glaze")
    P.cover("box", -46, -35, (1.2, 2.6, 2.4), 0, "cover_dark")
    P.column(-59.2, -34.0, 4.0, 0.4)                          # was inside the diagonal perimeter wall
    P.column(-54, -26, 4.0, 0.4)
    # temple: colonnade pairs, sarcophagi
    P.column(-46, -5.5, 5.5, 0.45)
    P.column(-46, 5.5, 5.5, 0.45)
    P.column(-38, -2.5, 5.5, 0.45)
    P.column(-38, 2.5, 5.5, 0.45)
    P.cover("box", -50.0, 7.7, (2.4, 0.9, 1.0), 0, "cover_stone")
    P.cover("box", -50.0, -7.7, (2.4, 0.9, 1.0), 0, "cover_stone")
    # alleys
    # (west alley lanes: north x -50..-45, south -40..-35, cistern -28..-23; the east lanes are 46..51, 36..41, 24..29)
    P.cover("box", -49.2, -16, (1.6, 1.3, 1.6), 0, "cover_stone", mirror=False)
    P.cover("box", 50.2, -16, (1.6, 1.3, 1.6), 0, "cover_stone", mirror=False)
    P.cover("box", -39.2, 15, (1.6, 1.3, 1.6), 0, "cover_stone", mirror=False)
    P.cover("box", 40.2, 15, (1.6, 1.3, 1.6), 0, "cover_stone", mirror=False)
    P.cover("box", -27.25, -14, (1.5, 1.2, 1.5), 0, "cover_stone", mirror=False)
    P.cover("box", 28.25, -14, (1.5, 1.2, 1.5), 0, "cover_stone", mirror=False)
    P.cover("box", -23.75, 12, (1.5, 1.2, 1.5), 0, "cover_stone", mirror=False)
    P.cover("box", 24.75, 12, (1.5, 1.2, 1.5), 0, "cover_stone", mirror=False)
    # plaza + court ring
    P.cover("box", -22.4, -6.5, (2.4, 1.1, 1.0), 0, "cover_glaze")    # flush with the plaza walls
    P.cover("box", -22.4, 7.5, (2.4, 1.1, 1.0), 0, "cover_glaze")
    P.column(-31, -2.6, 4.5, 0.4)                           # flush with the approach walls (a 0.36 m slit before)
    P.column(-31, 2.6, 4.5, 0.4)
    P.cover("box", -10.68, -6.08, (3.2, 1.2, 1.1), 45, "cover_stone")
    P.cover("box", -10.68, 6.08, (3.2, 1.2, 1.1), -45, "cover_stone")
    # south lanes / chapel / basin
    P.cover("box", -40, 28, (2.6, 1.2, 1.2), 0, "cover_glaze")
    P.cover("box", -51.5, 29, (3.0, 1.2, 1.2), 0, "cover_stone")             # mid court, off the phase gate (-50,34.5)
    P.cover("box", -30.5, 22.0, (1.2, 0.9, 2.4), 0, "cover_stone")     # chapel pews (flush with the north wall)
    P.cover("box", -30.5, 32.0, (1.2, 0.9, 2.4), 0, "cover_stone")
    P.cover("cyl", -14, 27, (0.7, 1.4), mat="cover_dark")
    P.cover("box", -9, 31, (2.6, 1.0, 1.0), 0, "cover_stone")          # basin benches
    P.cover("box", -9, 22, (2.6, 1.0, 1.0), 0, "cover_stone")
    # terraces
    P.cover("box", -36, -27, (3.0, 1.1, 1.0), 0, "cover_glaze", y0=TR)
    P.cover("box", -22, -34.5, (1.0, 1.1, 3.0), 0, "cover_glaze", y0=TR)
    P.column(-39.5, -36.2, 4.2, 0.35, y0=TR)
    P.column(-39.5, -26.0, 4.2, 0.35, y0=TR)
    P.column(-17.5, -26.0, 4.2, 0.35, y0=TR)
    P.cover("box", 0, -27, (3.0, 1.1, 1.0), 0, "cover_glaze", y0=TR, mirror=False)
    # parapets along the terrace's south edge (stairs/ladder gaps left open)
    P.wall((-41, -24.3), (-28.2, -24.3), 1.1, 0.4, "wall_a", y0=TR)
    P.wall((-23.8, -24.3), (-15, -24.3), 1.1, 0.4, "wall_a", y0=TR)

    # ---------------------------------------------------------------- temporal barricades (restorable cover)
    P.prop(-54, -30, (3.0, 1.6, 0.5), 90, color="E8DFC8")                  # reliquary yard
    P.prop(-7.07, 7.07, (2.6, 1.6, 0.5), 135, color="E8DFC8")              # court ring (it sat inside the diagonal wall)
    P.prop(-46.1, -12, (2.2, 1.5, 0.5), 0, color="E8DFC8", mirror=False)   # north alley, hugging the inner wall
    P.prop(47.1, -12, (2.2, 1.5, 0.5), 0, color="E8DFC8", mirror=False)
    P.prop(-36.1, 18, (2.2, 1.5, 0.5), 0, color="E8DFC8", mirror=False)    # south alley
    P.prop(37.1, 18, (2.2, 1.5, 0.5), 0, color="E8DFC8", mirror=False)
    P.prop(-36.5, 29.5, (0.5, 1.6, 2.6), 0, color="E8DFC8")                # south lane (clear of the glazed cover at -40 and the spawn/shard at z 25.5-26)
    P.prop(-61.0, 12, (2.0, 1.6, 0.5), 0, color="E8DFC8", mirror=False)    # south exit corridor: a 2.6 m barricade left 0.7 m gaps = sealed
    P.prop(62.0, 12, (2.0, 1.6, 0.5), 0, color="E8DFC8", mirror=False)

    # ---------------------------------------------------------------- spawns / objectives / modes
    P.set_layout([-43, 0, 0], [43, 0, 0], [-56, 0, -31], [56, 0, -31], [[-30, 3, -31], [30, 3, -31]], 8.0, 1.6)
    P.spawn_west([(-65, -4.5, -90), (-65, 4.5, -90), (-62, -1.5, -90), (-62, 1.5, -90)])
    P.ffa([[-64, -3.2, -90], [-64, 3.2, -90], [-52, -31, 0], [-30, -31, 0], [0, -16, 180], [7, 25.5, 0], [-26, 4, 90], [-37, 26, 90],
           [64, -3.2, 90], [64, 3.2, 90], [52, -31, 180], [30, -31, 180], [26, -4, -90], [37, 26, -90], [-10, 1.5, 0], [10, -1.5, 180]])
    P.shards([[0, 0.5, 11], [-30, 3.5, -31], [30, 3.5, -31], [0, -1.1, 22], [-37.5, 0.5, 25.5], [37.5, 0.5, 25.5], [-52, 0.5, -30], [52, 0.5, -30]])
    P.beacons([[0, 0.5, -12], [-30, 3, -31], [30, 3, -31], [0, -1.6, 22]])
    P.solidify(h=(8.0, 12.0), maxdim=14.0)
    seal_voids(P)
    P.slivers = P.fill_slivers()
    return P


# 1 m wide voids that solidify() leaves beside rooms (its polygon raster covers one pixel row more on the +x / +z side of a
# street, room or platform, so the 1 m fill cell next to it is dropped). Where such a void is not part of a street it is a
# hollow slot: a sealed gap in the building line, or a dead end a player can wedge into. Street-side margins stay as they are
# (the carry routes were tuned on them).
SEALS = [[52, -9, 53, 9], [22, 34, 34, 35], [-34, 34, -22, 35], [-52, 9, -41, 10], [41, 9, 52, 10], [-34, -9, -33, -4],
         [34, 20, 35, 23], [-22, 20, -21, 22], [-34, 4, -33, 9], [-22, 30, -21, 34],
         [34, 9, 36, 10], [-12, 34, 12, 35], [12, 18, 13, 22], [12, 31, 13, 34]]      # last three: 1 m shelves round the sunken basin


def seal_voids(P):
    for i, r in enumerate(SEALS):
        cx, cz = (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0
        mat = ("wall_a", "wall_b", "wall_c")[int(abs(math.floor(cx / 7.0) * 31 + math.floor(cz / 7.0) * 17)) % 3]
        P.ops.append({"op": "block", "r": [float(v) for v in r], "h": 9.0 + (i % 3), "mat": mat, "y0": 0.0, "derived": True, "fill": True, "seal": True})


if __name__ == "__main__":
    P = build()
    if "gen" in sys.argv:
        print("emitted", P.emit_gd("src/maps/plans/oracle_plan.gd"), "ops")
        P.build()
        os.makedirs("assets/ui", exist_ok=True)
        P.render_preview("assets/ui/map_oracle_gardens.png")
        sys.exit(0)
    spawn = {"spawn_W": (-62, 3), "vault_W": (-43, 0), "stab_W": (-56, -31), "court": (0, 0), "terraceA": (-30, -31)}
    report(P, spawn_xz=spawn, heat_png="build/maps/oracle_heat.png", plan_png="build/maps/oracle_plan.png", sight_layers=(0.0, 3.0))
