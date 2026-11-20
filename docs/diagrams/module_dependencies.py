"""Module-level import dependencies of the Atlas Flutter app, from a Graphify graph.

Reads graphify-out/graph.json (built by `graphify update .`), keeps the `imports`
edges between Dart files under lib/, resolves package: and relative imports to lib
paths, groups them by layer and prints the counts. The numbers in
docs/diagrams/flutter_module_dependencies.md come from this script.

    graphify update .
    python docs/diagrams/module_dependencies.py
"""
import collections
import json
import posixpath

GRAPH = "graphify-out/graph.json"

LAYERS = {
    "navigation": "navigation",
    "screens": "screens",
    "widgets": "widgets",
    "providers": "providers",
    "models": "models",
    "data": "data",
    "repositories": "repositories",
    "ai_form_coach": "ai_form_coach",
    "config": "config",
}


def layer(path):
    parts = path.split("/")
    if len(parts) == 2:
        return "app (main, theme)"
    if parts[1] == "services":
        return "services"
    return LAYERS.get(parts[1], parts[1])


def main():
    g = json.load(open(GRAPH, encoding="utf-8"))
    nodes = {n["id"]: n for n in g["nodes"]}
    counts = collections.Counter()
    total = 0
    for e in g["links"]:
        if e["relation"] != "imports":
            continue
        s, t = nodes.get(e["source"]), nodes.get(e["target"])
        if not s or not t:
            continue
        sf = s.get("source_file") or ""
        label = t.get("label") or ""
        if not sf.startswith("lib/"):
            continue
        if label.startswith("package:atlas/"):
            tp = "lib/" + label[len("package:atlas/"):]
        elif label.startswith("."):
            tp = posixpath.normpath(posixpath.join(posixpath.dirname(sf), label))
        else:
            continue
        if not tp.startswith("lib/"):
            continue
        total += 1
        a, b = layer(sf), layer(tp)
        if a != b:
            counts[(a, b)] += 1
    print("lib-to-lib import edges (all):", total)
    print("| From | To | Imports |")
    print("|---|---|---:|")
    for (a, b), c in sorted(counts.items(), key=lambda x: -x[1])[:25]:
        print(f"| {a} | {b} | {c} |")


if __name__ == "__main__":
    main()
