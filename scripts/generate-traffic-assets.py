#!/usr/bin/env python3
"""Turns raw GitHub traffic API responses into the committed, README-facing
assets: a retained history file (GitHub's own API only ever returns a
rolling 14-day window, so this script is what keeps anything older than
that), two shields.io "endpoint" badge JSON files, and one animated SVG
trend chart. Pure stdlib -- runs on the GitHub Actions ubuntu runner with
no extra pip install.

Usage:
  generate-traffic-assets.py <views.json> <clones.json> <out_dir>

  <views.json> / <clones.json>: raw bodies from
    GET /repos/{owner}/{repo}/traffic/views
    GET /repos/{owner}/{repo}/traffic/clones
  <out_dir>: where to write traffic.json, views-badge.json,
    clones-badge.json, traffic-chart.svg, and traffic-history.json (read
    back in if it already exists there, so history accumulates across runs
    instead of being clobbered to just the latest 14-day window).

Exit 0 on success. Exit 1 on bad input (caller should treat as "nothing to
commit this run", not crash the workflow).
"""
import datetime
import json
import os
import sys


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def merge_history(existing, new_daily, key):
    """existing: list of {"date": "YYYY-MM-DD", "views": N, "clones": N}.
    new_daily: the API's own "views"/"clones" list of {"timestamp", "count",
    "uniques"}. Merges by date, the new window's numbers winning for any
    date both sides have (GitHub's own count for a day it already reported
    can still tick up a little as the day's data settles), then keeps the
    merged list sorted and capped so the file doesn't grow forever.
    """
    by_date = {row["date"]: dict(row) for row in existing}
    for entry in new_daily:
        date = entry["timestamp"][:10]
        row = by_date.setdefault(date, {"date": date, "views": 0, "clones": 0, "views_uniques": 0, "clones_uniques": 0})
        row[key] = entry["count"]
        row[f"{key}_uniques"] = entry["uniques"]
    merged = sorted(by_date.values(), key=lambda r: r["date"])
    MAX_DAYS = 400
    return merged[-MAX_DAYS:]


def badge_json(label, value, color):
    return {"schemaVersion": 1, "label": label, "message": str(value), "color": color}


def svg_chart(history, width=860, height=200):
    """A real, data-driven area chart (views + clones, last 90 days of
    whatever history exists) with a left-to-right SMIL draw-in animation on
    load and a light/dark variant via an embedded media query -- the same
    technique animated README badges (e.g. readme-typing-svg) already rely
    on, confirmed to render correctly embedded as a plain <img> in a GitHub
    README.
    """
    recent = history[-90:] if len(history) > 90 else history[:]
    if not recent:
        recent = [{"date": datetime.date.today().isoformat(), "views": 0, "clones": 0}]
    pad_l, pad_r, pad_t, pad_b = 46, 16, 16, 28
    plot_w = width - pad_l - pad_r
    plot_h = height - pad_t - pad_b
    n = len(recent)
    max_v = max(1, max(r.get("views", 0) for r in recent))
    max_c = max(1, max(r.get("clones", 0) for r in recent))
    max_y = max(max_v, max_c)

    def x_at(i):
        return pad_l + (plot_w * i / max(1, n - 1))

    def y_at(v):
        return pad_t + plot_h - (plot_h * v / max_y)

    views_pts = [(x_at(i), y_at(r.get("views", 0))) for i, r in enumerate(recent)]
    clones_pts = [(x_at(i), y_at(r.get("clones", 0))) for i, r in enumerate(recent)]

    def path_d(pts):
        return "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts)

    def area_d(pts):
        d = path_d(pts)
        last_x, _ = pts[-1]
        first_x, _ = pts[0]
        base_y = pad_t + plot_h
        return f"{d} L {last_x:.1f},{base_y:.1f} L {first_x:.1f},{base_y:.1f} Z"

    total_views = sum(r.get("views", 0) for r in recent)
    total_clones = sum(r.get("clones", 0) for r in recent)
    start_date = recent[0]["date"]
    end_date = recent[-1]["date"]
    path_len = sum(
        ((views_pts[i][0] - views_pts[i - 1][0]) ** 2 + (views_pts[i][1] - views_pts[i - 1][1]) ** 2) ** 0.5
        for i in range(1, len(views_pts))
    ) or 1

    # No CSS custom properties: confirmed by direct testing (librsvg,
    # commonly used outside real browsers) that when a renderer doesn't
    # resolve var(...), the declaration still wins the cascade over any
    # presentation attribute, but computes to the property's own initial
    # value (black, for `fill`) -- not to the presentation attribute and
    # not to the light-mode intent either, so the whole chart rendered as
    # a solid black box. A plain unconditional rule per class, overridden
    # by a media-scoped rule a renderer either understands (applies it) or
    # doesn't (ignores the whole block, leaving the light-mode rule in
    # effect), degrades correctly either way -- confirmed the light-mode
    # rule alone renders correctly under librsvg, which has no @media
    # support at all.
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif">
  <style>
    .bg {{ fill: #ffffff; }}
    .grid {{ stroke: #e8e8ec; stroke-width: 1; }}
    .label {{ fill: #6e7781; font-size: 11px; }}
    .title {{ fill: #1f2328; font-size: 13px; font-weight: 600; }}
    .views-fg {{ fill: #6b46c1; stroke: #6b46c1; }}
    .clones-fg {{ fill: #10a37f; stroke: #10a37f; }}
    .views-area {{ fill: #6b46c1; fill-opacity: 0.20; opacity: 0; animation: fadein 1s ease-out 0.6s forwards; }}
    .clones-area {{ fill: #10a37f; fill-opacity: 0.15; opacity: 0; animation: fadein 1s ease-out 0.75s forwards; }}
    @media (prefers-color-scheme: dark) {{
      .bg {{ fill: #0d1117; }}
      .grid {{ stroke: #2a2f37; }}
      .label {{ fill: #8b949e; }}
      .title {{ fill: #e6edf3; }}
      .views-fg {{ fill: #a78bfa; stroke: #a78bfa; }}
      .clones-fg {{ fill: #34d399; stroke: #34d399; }}
      .views-area {{ fill: #a78bfa; fill-opacity: 0.20; }}
      .clones-area {{ fill: #34d399; fill-opacity: 0.15; }}
    }}
    .views-line {{ fill: none; stroke-width: 2; stroke-dasharray: {path_len:.0f}; stroke-dashoffset: {path_len:.0f}; animation: draw 1.4s ease-out forwards; }}
    .clones-line {{ fill: none; stroke-width: 2; stroke-dasharray: {path_len:.0f}; stroke-dashoffset: {path_len:.0f}; animation: draw 1.4s ease-out 0.15s forwards; }}
    @keyframes draw {{ to {{ stroke-dashoffset: 0; }} }}
    @keyframes fadein {{ to {{ opacity: 1; }} }}
    .dot {{ animation: pulse 2s ease-in-out infinite; }}
    @keyframes pulse {{ 0%,100% {{ r: 3; opacity: 1; }} 50% {{ r: 5; opacity: 0.6; }} }}
  </style>
  <rect class="bg" width="{width}" height="{height}" rx="8"/>
  <text x="{pad_l}" y="16" class="title">GitHub traffic — {start_date} to {end_date}</text>
  <text x="{width - pad_r}" y="16" text-anchor="end" class="label"><tspan class="views-fg">● {total_views} views</tspan>   <tspan class="clones-fg">● {total_clones} clones</tspan></text>
  {''.join(f'<line class="grid" x1="{pad_l}" y1="{pad_t + plot_h * f:.1f}" x2="{width - pad_r}" y2="{pad_t + plot_h * f:.1f}"/>' for f in (0, 0.5, 1))}
  <path class="views-area" d="{area_d(views_pts)}"/>
  <path class="clones-area" d="{area_d(clones_pts)}"/>
  <path class="views-line views-fg" d="{path_d(views_pts)}"/>
  <path class="clones-line clones-fg" d="{path_d(clones_pts)}"/>
  <circle class="dot views-fg" cx="{views_pts[-1][0]:.1f}" cy="{views_pts[-1][1]:.1f}" r="3"/>
  <circle class="dot clones-fg" cx="{clones_pts[-1][0]:.1f}" cy="{clones_pts[-1][1]:.1f}" r="3"/>
  <text x="{pad_l}" y="{height - 8}" class="label">{n} day(s) retained · updates daily via .github/workflows/traffic.yml</text>
</svg>
"""


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 1
    views_path, clones_path, out_dir = argv
    try:
        views_raw = load_json(views_path)
        clones_raw = load_json(clones_path)
    except Exception as e:
        print(f"Could not read input JSON: {e}", file=sys.stderr)
        return 1

    os.makedirs(out_dir, exist_ok=True)
    history_path = os.path.join(out_dir, "traffic-history.json")
    existing = load_json(history_path) if os.path.exists(history_path) else []

    history = merge_history(existing, views_raw.get("views", []), "views")
    history = merge_history(history, clones_raw.get("clones", []), "clones")

    with open(history_path, "w", encoding="utf-8") as fh:
        json.dump(history, fh, indent=2)

    summary = {
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "window_14d": {
            "views": views_raw.get("count", 0),
            "views_uniques": views_raw.get("uniques", 0),
            "clones": clones_raw.get("count", 0),
            "clones_uniques": clones_raw.get("uniques", 0),
        },
        "all_time_retained": {
            "since": history[0]["date"] if history else None,
            "views": sum(r.get("views", 0) for r in history),
            "clones": sum(r.get("clones", 0) for r in history),
        },
    }
    with open(os.path.join(out_dir, "traffic.json"), "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2)

    with open(os.path.join(out_dir, "views-badge.json"), "w", encoding="utf-8") as fh:
        json.dump(badge_json("views (14d)", views_raw.get("count", 0), "6b46c1"), fh)
    with open(os.path.join(out_dir, "clones-badge.json"), "w", encoding="utf-8") as fh:
        json.dump(badge_json("clones (14d)", clones_raw.get("count", 0), "10a37f"), fh)

    with open(os.path.join(out_dir, "traffic-chart.svg"), "w", encoding="utf-8") as fh:
        fh.write(svg_chart(history))

    print(f"Wrote traffic assets to {out_dir}: {len(history)} day(s) of retained history.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
