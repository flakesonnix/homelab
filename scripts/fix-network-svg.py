#!/usr/bin/env python3
import re
import sys


def fix_network_svg(input_path, output_path):
    with open(input_path) as f:
        svg = f.read()

    # Collect all port label text elements
    label_pattern = (
        r'(<text[^>]*) y="([\d.]+)"([^>]*dominant-baseline="hanging"'
        r'[^>]*style="font:12px JetBrains Mono"[^>]*>[^<]+</text>)'
    )

    labels = []
    for m in re.finditer(label_pattern, svg):
        prefix = m.group(1)
        y = float(m.group(2))
        suffix = m.group(3)
        xm = re.search(r'x="([\d.]+)"', prefix)
        x = float(xm.group(1)) if xm else 0
        labels.append({
            'orig_y': y, 'x': x,
            'full': m.group(0),
            'start': m.start(), 'end': m.end(),
        })

    if not labels:
        print("No interface labels found, skipping", file=sys.stderr)
        with open(output_path, 'w') as f:
            f.write(svg)
        return

    labels.sort(key=lambda l: l['orig_y'])
    print(f"Found {len(labels)} port labels", file=sys.stderr)

    # Simple approach: enforce minimum 16px between ALL consecutive labels
    min_spacing = 16
    adj = {}
    cursor = labels[0]['orig_y']
    for l in labels:
        candidate = cursor
        if candidate > l['orig_y']:
            adj[l['orig_y']] = candidate
        else:
            adj[l['orig_y']] = l['orig_y']
        cursor = adj[l['orig_y']] + 12 + min_spacing

    # Collect all port icon paths for mireo's interface ports
    icon_pattern = r'(M178\.6 ([\d.]+))h8v8h-8z'
    icons = {}
    for m in re.finditer(icon_pattern, svg):
        path_y = float(m.group(2))
        icons[path_y] = m.group(0)

    # Apply adjustments from rightmost position (to preserve earlier offsets)
    for l in reversed(labels):
        old_y = l['orig_y']
        new_y = adj[old_y]
        if abs(new_y - old_y) < 0.01:
            continue

        # Replace y in the text element
        old_str = f'y="{old_y}"'
        new_str = f'y="{new_y:.3f}"'
        new_full = l['full'].replace(old_str, new_str)
        svg = svg[:l['start']] + new_full + svg[l['end']:]

        # Replace port icon at old_y + 2
        old_icon_y = old_y + 2
        new_icon_y = new_y + 2
        old_icon = f'M178.6 {old_icon_y:.3f}h8v8h-8z'
        new_icon = f'M178.6 {new_icon_y:.3f}h8v8h-8z'
        svg = svg.replace(old_icon, new_icon)

    # Fix SVG viewBox height
    last_y = adj[labels[-1]['orig_y']]
    new_content_height = last_y + 12 + 20

    hm = re.search(r'(<svg[^>]*height=")([\d.]+)(")', svg)
    if hm:
        orig_h = float(hm.group(2))
        new_h = max(new_content_height, orig_h)
        svg = svg[:hm.start(2)] + f"{new_h:.3f}" + svg[hm.end(2):]

    with open(output_path, 'w') as f:
        f.write(svg)

    print(f"Fixed {len(labels)} labels (min spacing = {min_spacing}px)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.svg> <output.svg>", file=sys.stderr)
        sys.exit(1)
    fix_network_svg(sys.argv[1], sys.argv[2])
