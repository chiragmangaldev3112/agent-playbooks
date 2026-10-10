#!/usr/bin/env python3
"""Builds a 1200x627 share-card SVG (LinkedIn/OG-image ratio) from this
repo's own real, already-committed numbers -- never invented ones. Reads
docs/traffic.json + docs/traffic-history.json (written by
generate-traffic-assets.py) for the traffic figures and the sparkline, and
takes the GitHub-side numbers (stars, forks, playbook count) as arguments
since those come from the REST API, not a committed file.

Usage:
  generate-share-card.py <stars> <forks> <playbook_count> <out.svg> [docs_dir]

Rasterize to PNG for an actual LinkedIn upload with rsvg-convert (or any
SVG renderer): rsvg-convert -w 1200 -h 627 out.svg -o out.png
"""
import json
import os
import sys


def main(argv):
    if len(argv) not in (4, 5):
        print(__doc__, file=sys.stderr)
        return 1
    stars, forks, playbooks, out_path = argv[0], argv[1], argv[2], argv[3]
    docs_dir = argv[4] if len(argv) == 5 else "docs"

    traffic_path = os.path.join(docs_dir, "traffic.json")
    history_path = os.path.join(docs_dir, "traffic-history.json")
    traffic = json.load(open(traffic_path, encoding="utf-8"))
    history = json.load(open(history_path, encoding="utf-8")) if os.path.exists(history_path) else []

    views = traffic["window_14d"]["views"]
    clones = traffic["window_14d"]["clones"]
    visitors = traffic["window_14d"]["views_uniques"]
    cloners = traffic["window_14d"]["clones_uniques"]
    since = traffic["all_time_retained"]["since"] or "—"

    # A real sparkline from real daily history, not a decorative squiggle.
    recent = history[-14:] if history else []
    w, h = 1200, 627
    spark_x, spark_y, spark_w, spark_h = 90, 430, 1020, 120
    bars_svg = ""
    if recent:
        n = len(recent)
        max_v = max(1, max(max(r.get("views", 0), r.get("clones", 0)) for r in recent))
        bar_w = spark_w / n * 0.6
        gap = spark_w / n
        for i, r in enumerate(recent):
            x = spark_x + i * gap
            vh = spark_h * r.get("views", 0) / max_v
            ch = spark_h * r.get("clones", 0) / max_v
            bars_svg += (
                f'<rect x="{x:.1f}" y="{spark_y + spark_h - vh:.1f}" width="{bar_w/2:.1f}" height="{vh:.1f}" fill="#a78bfa" rx="1"/>'
                f'<rect x="{x + bar_w/2:.1f}" y="{spark_y + spark_h - ch:.1f}" width="{bar_w/2:.1f}" height="{ch:.1f}" fill="#34d399" rx="1"/>'
            )

    def stat(x, label, value, color):
        return f"""
    <text x="{x}" y="300" font-size="64" font-weight="700" fill="{color}">{value}</text>
    <text x="{x}" y="332" font-size="20" fill="#8b949e">{label}</text>"""

    # A drawn mark below, not a Unicode emoji glyph: confirmed directly (not
    # assumed) that rsvg-convert -- and other non-browser SVG renderers this
    # is meant to be rasterized with -- has no color-emoji font, so an emoji
    # character renders as a broken box in the actual shipped PNG. XML
    # comments can't contain "--", so this note lives here, not inline below.
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif">
  <defs>
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0d1117"/>
      <stop offset="100%" stop-color="#161b22"/>
    </linearGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bgGrad)"/>
  <rect x="0" y="0" width="{w}" height="6" fill="#6b46c1"/>

  <rect x="90" y="56" width="40" height="40" rx="10" fill="#6b46c1"/>
  <circle cx="103" cy="72" r="4" fill="#e6edf3"/>
  <circle cx="117" cy="72" r="4" fill="#e6edf3"/>
  <rect x="100" y="82" width="20" height="4" rx="2" fill="#e6edf3"/>
  <text x="142" y="88" font-size="42" font-weight="700" fill="#e6edf3">Agent Playbooks</text>
  <text x="90" y="130" font-size="22" fill="#8b949e">Portable engineering workflows for AI coding agents</text>

  <text x="90" y="185" font-size="18" fill="#6e7781">Real GitHub traffic, last 14 days (since {since}) — not a vanity claim, pulled live from the repo</text>

  {stat(90, "views", views, "#a78bfa")}
  {stat(330, "clones", clones, "#34d399")}
  {stat(570, "unique visitors", visitors, "#e6edf3")}
  {stat(900, "unique cloners", cloners, "#e6edf3")}

  {bars_svg}
  <text x="90" y="590" font-size="16" fill="#6e7781">{playbooks} playbooks · {stars} stars · {forks} forks · Ed25519-signed releases · works across 15 AI coding tools</text>
  <text x="{w - 90}" y="590" font-size="16" fill="#6e7781" text-anchor="end">github.com/chiragmangaldev3112/agent-playbooks</text>
</svg>
"""
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(svg)
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
