"""Plot a saved token audit without rereading or modifying protected sessions."""
import argparse
import csv
import json
import math
import os
from pathlib import Path
import re
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def order(entry):
    pid = entry["prompt_id"]
    match = re.search(r"P(\d+)(?:-(\d+))?$", pid)
    return (pid[:match.start()] if match else pid,
            int(match[1]) if match else 0, int(match[2] or 0) if match else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--output-prefix", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true", help="Replace this prefix's PNG/SVG/CSV outputs")
    args = parser.parse_args()
    audit_path = args.audit.resolve()
    prefix = args.output_prefix.resolve()
    if not prefix.is_relative_to(ROOT) or prefix == ROOT:
        raise ValueError("Output prefix must be inside the repository")
    if any(part in (".git", ".codex") for part in prefix.relative_to(ROOT).parts):
        raise ValueError("Cannot write into protected metadata directories")
    outputs = [Path(str(prefix) + suffix) for suffix in (".png", ".svg", ".csv")]
    if not args.overwrite and any(p.exists() for p in outputs):
        raise FileExistsError("Plot output exists; choose a fresh prefix")
    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    entries = audit["entries"]
    if len({e["prompt_id"] for e in entries}) != len(entries):
        raise ValueError("Audit has duplicate prompt IDs")
    for entry in entries:
        if entry["status"] != "Unavailable":
            usage = entry["evidence"]["usage"]
            if usage["input_tokens"] + usage["output_tokens"] != usage["total_tokens"]:
                raise ValueError("Audit token arithmetic mismatch")
    prefix.parent.mkdir(parents=True, exist_ok=True)
    # Keep even matplotlib's temporary configuration/font cache in the repo.
    with tempfile.TemporaryDirectory(prefix=".plot-cache-", dir=prefix.parent) as cache:
        previous = os.environ.get("MPLCONFIGDIR")
        os.environ["MPLCONFIGDIR"] = cache
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt
            from matplotlib.ticker import FuncFormatter, MaxNLocator

            plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11,
                                 "axes.spines.top": False, "axes.spines.right": False,
                                 "axes.spines.left": False, "axes.spines.bottom": False,
                                 "axes.titleweight": "bold", "axes.labelcolor": "#374151",
                                 "text.color": "#172b4d", "xtick.color": "#475569",
                                 "ytick.color": "#475569", "svg.fonttype": "none"})
            fig, axes = plt.subplots(2, 1, figsize=(18, 12), gridspec_kw={"height_ratios": [1.15, 1]})
            fig.patch.set_facecolor("#f8fafc")
            fig.subplots_adjust(top=.84, bottom=.26, left=.08, right=.97, hspace=.85)
            fig.text(.08, .946, "Token usage by prompt", fontsize=27, weight="bold")
            fig.text(.08, .910, f"Recorded input + output  |  Audit {audit['audit_id']}  |  "
                     f"Snapshot {audit['recorded_at_utc'][:10]}", fontsize=12, color="#64748b")
            for ax, imported in zip(axes, (False, True)):
                rows = sorted((e for e in entries if ("-" in e["prompt_id"]) == imported), key=order)
                labels = [e["prompt_id"] for e in rows]
                complete = [e["evidence"]["usage"]["total_tokens"] if e["status"] == "completed"
                            else math.nan for e in rows]
                # A NaN at every unavailable/partial entry breaks the complete line.
                ax.set_facecolor("white")
                ax.plot(range(len(rows)), complete, color="#087f8c", linewidth=1.8,
                        marker="o", markersize=4.2, label="Verified completed usage", zorder=3)
                partial_x = [i for i, e in enumerate(rows) if e["status"] == "partial"]
                ax.scatter(partial_x, [rows[i]["evidence"]["usage"]["total_tokens"] for i in partial_x],
                           marker="D", s=65, color="#d97706", label="Partial observed usage", zorder=4)
                title = "Branch-qualified prompt records" if imported else "Local prompt sequence"
                unavailable = sum(e["status"] == "Unavailable" for e in rows)
                ax.set_title(f"{title}   |   {len(rows)} records; {unavailable} unavailable", loc="left", pad=14)
                ax.set_ylabel("Tokens (millions)")
                ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f"{value / 1_000_000:g}M"))
                ax.yaxis.set_major_locator(MaxNLocator(5))
                ax.set_ylim(bottom=0)
                ax.set_xlim(-1, max(len(rows), 1))
                stride = 1 if imported else 3
                ticks = sorted(set(range(0, len(rows), stride)) | ({len(rows)-1} if rows else set()))
                ax.set_xticks(ticks, [labels[i] for i in ticks], rotation=40 if imported else 55,
                              ha="right", fontsize=8 if imported else 9)
                ax.set_xlabel("Prompt ID (numeric order within each ID sequence)", labelpad=9)
                ax.grid(axis="y", color="#e2e8f0", linewidth=.8)
                ax.tick_params(axis="both", length=0, pad=8)
                if any(math.isfinite(value) for value in complete):
                    peak = max((value, i) for i, value in enumerate(complete) if math.isfinite(value))
                    ax.annotate(f"{labels[peak[1]]}: {peak[0]:,}", (peak[1], peak[0]),
                                xytext=(-8, 12), textcoords="offset points", ha="right", fontsize=10)
                    ax.set_ylim(top=max(ax.get_ylim()[1], peak[0]*1.22))
            axes[0].legend(loc="upper left", frameon=False, fontsize=10)
            counts = audit["counts"]
            fig.text(.08, .074, f"{counts['completed']} completed  /  {counts['partial']} partial  /  "
                     f"{counts['Unavailable']} unavailable     |     "
                     f"Verified subtotal: {audit['totals']['completed']['total_tokens']:,} tokens",
                     fontsize=12, weight="bold")
            fig.text(.08, .042, "Gaps mean unavailable, not zero. Partial markers are not final totals. "
                     "Panels use independent y-axis ranges; cached input is already included.",
                     fontsize=10, color="#64748b")
            fig.text(.08, .022, "Saved audit snapshot; later prompts are not included. "
                     "Lines connect adjacent available records and do not bridge evidence gaps.",
                     fontsize=10, color="#64748b")
            fig.savefig(outputs[0], dpi=180, facecolor=fig.get_facecolor())
            fig.savefig(outputs[1], facecolor=fig.get_facecolor(), metadata={"Date": None})
            plt.close(fig)
        finally:
            if previous is None:
                os.environ.pop("MPLCONFIGDIR", None)
            else:
                os.environ["MPLCONFIGDIR"] = previous
    with outputs[2].open("w" if args.overwrite else "x", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["prompt_id", "status", "input_tokens", "cached_input_tokens",
                         "output_tokens", "total_tokens", "usage_cutoff_utc"])
        for entry in sorted(entries, key=order):
            evidence = entry.get("evidence", {})
            usage = evidence.get("usage", {})
            writer.writerow([entry["prompt_id"], entry["status"], usage.get("input_tokens", ""),
                             usage.get("cached_input_tokens", ""), usage.get("output_tokens", ""),
                             usage.get("total_tokens", ""), evidence.get("cutoff_utc", "")])
    print(json.dumps({"audit": audit["audit_id"], "records": len(entries),
                      "files": [str(p.relative_to(ROOT)) for p in outputs]}))


if __name__ == "__main__":
    main()
