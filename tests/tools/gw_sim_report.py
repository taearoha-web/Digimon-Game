#!/usr/bin/env python3
"""Sums up tests/tools/guild_war_sim JSON lines (SIM_OUT): the doctrine ("new") against
the old commander ("old") - wins, places, kills/deaths, captures and when, gate falls,
switch time, wins by camp, retakes, the doctrine's phases and orders, stuck fighters and the doctrine's cost.
usage: python3 tests/tools/gw_sim_report.py results.jsonl [more.jsonl ...]
"""
import json
import sys
from collections import Counter, defaultdict


def load(paths):
    rows = []
    for p in paths:
        with open(p, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("{"):
                    rows.append(json.loads(line))
    return rows


def main(paths):
    rows = load(paths)
    groups = defaultdict(list)
    for r in rows:
        key = (r["teams"], tuple(r["mults"]) if len(set(r["mults"])) > 1 else "equal")
        groups[key].append(r)
    for key, wars in sorted(groups.items(), key=lambda kv: str(kv[0])):
        teams = key[0]
        stat = defaultdict(lambda: defaultdict(float))
        phases = Counter()
        n_side = Counter()
        for r in wars:
            winner = r["winner"]
            places = {p["team"]: p["place"] for p in r.get("places", [])}
            for t in range(teams):
                brain = "new" if int(r["smart"][t]) else "old"
                strong = r["mults"][t] > min(r["mults"]) if key[1] != "equal" else None
                tag = brain if strong is None else "%s(%s)" % (brain, "strong" if strong else "weak")
                s = stat[tag]
                n_side[tag] += 1
                s["wins"] += 1 if winner == t else 0
                s["place"] += places.get(t, 0)
                s["kills"] += r["kills"][t]
                s["deaths"] += r["deaths"][t]
                s["captures"] += r["captures_n"][t]
                s["holds_at_bell"] += 1 if r["owner"] == t else 0
                s["switch_s"] += r["switch_s"][t]
                firsts = [c[0] for c in r["capture_log"] if c[1] == t]
                if firsts:
                    s["first_cap"] += firsts[0]
                    s["cap_wars"] += 1
                if brain == "new":
                    for ph, sec in r["phases"][t].items():
                        phases[ph] += sec
        print("== %d guilds, strength %s: %d wars ==" % (teams, key[1], len(wars)))
        print("%-14s %5s %6s %6s %6s %5s %6s %7s %9s %8s" % ("side", "n", "win%", "place", "K", "D", "K/D", "caps", "1st cap s", "holds"))
        for tag in sorted(stat):
            s = stat[tag]
            n = n_side[tag]
            kd = s["kills"] / max(1.0, s["deaths"])
            first = s["first_cap"] / s["cap_wars"] if s["cap_wars"] else float("nan")
            print("%-14s %5d %5.0f%% %6.2f %6.1f %5.1f %6.2f %7.2f %9.0f %7.0f%%" % (
                tag, n, 100.0 * s["wins"] / n, s["place"] / n, s["kills"] / n, s["deaths"] / n, kd,
                s["captures"] / n, first, 100.0 * s["holds_at_bell"] / n))
        # Camp bias: wins by camp (team 0 west, 1 east, ...), whatever the brains.
        camps = Counter(r["winner"] for r in wars)
        print("wins by camp: " + ", ".join("t%d %d (%.0f%%)" % (t, camps[t], 100.0 * camps[t] / len(wars)) for t in range(teams)))
        # A held castle taken by another guild (every capture after the first is one).
        held = [r for r in wars if r.get("capture_log")]
        retaken = [r for r in held if len(r["capture_log"]) > 1]
        both = [r["first_both"] for r in wars if r.get("first_both", -1) is not None and r.get("first_both", -1) >= 0]
        print("captures per war %.2f | held castles retaken %d of %d | first both switches %s s | rule %s" % (
            sum(len(r.get("capture_log", [])) for r in wars) / len(wars), len(retaken), len(held),
            "%.0f" % (sum(both) / len(both)) if both else "-", ",".join(sorted(set(str(r.get("rule", "-")) for r in wars)))))
        tiers = [[r["tiers"][k] for r in wars if r["tiers"][k] >= 0] for k in range(3)]
        print("tier open (avg s): %s" % ", ".join("%.0f" % (sum(t) / len(t)) if t else "-" for t in tiers))
        stuck = max(r.get("stuck_max", 0) for r in wars)
        peak = max(r.get("doctrine_peak_ms", 0) for r in wars)
        think_avg = max(r.get("doctrine_think_avg_us", 0) for r in wars)
        apply_avg = max(r.get("doctrine_apply_avg_us", 0) for r in wars)
        frame = sum(r.get("frame_avg_ms", 0) for r in wars) / len(wars)
        orders = [o for r in wars for t, o in enumerate(r.get("orders", [])) if int(r["smart"][t])]
        print("longest stuck fighter %.0f s | doctrine think peak %.2f ms, avg %d us, layout avg %d us | frame avg %.2f ms | orders per war per guild %.1f" % (
            stuck, peak, think_avg, apply_avg, frame, sum(orders) / max(1, len(orders))))
        total = sum(phases.values())
        if total:
            print("new phases: " + ", ".join("%s %.0f%%" % (k, 100.0 * v / total) for k, v in phases.most_common()))
        print()


if __name__ == "__main__":
    main(sys.argv[1:])
