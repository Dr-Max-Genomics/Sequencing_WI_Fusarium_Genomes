#!/usr/bin/env python3
"""
telomere_density.py
-------------------
Compute telomeric motif density along contigs of a genome FASTA.

Usage (interactive / standalone):
    python telomere_density.py -i genome.fasta -o telomere_density.tsv --outdir plots/

Usage (via SLURM array wrapper):
    Called by 10_telomere_search.sh — see that script for submission details.

Output:
    - TSV: contig, start, end, length_bp, motif_count, motifs_per_kb
    - PNG:  one plot per contig saved to --outdir

Telomeric motifs searched (both strands):
    Forward: CCTA(G) family  — C{2,4}T{1,2}A{1,3}
    Reverse: TTAGG family    — T{1,3}A{1,2}G{2,4}
"""

import argparse
import re
import os
import sys

# ---------------------------------------------------------------------------
# Graceful Bio import with actionable error message
# ---------------------------------------------------------------------------
try:
    from Bio import SeqIO
except ImportError:
    sys.exit(
        "\nERROR: Biopython not found.\n"
        "Activate the correct environment before running:\n"
        "    module load miniconda\n"
        "    source activate seqenv\n"
        "Then retry.\n"
    )

try:
    import matplotlib
    matplotlib.use("Agg")   # non-interactive backend — safe for HPC nodes
    import matplotlib.pyplot as plt
except ImportError:
    sys.exit(
        "\nERROR: matplotlib not found.\n"
        "Install it in your environment:\n"
        "    conda install -c conda-forge matplotlib\n"
    )

# ---------------------------------------------------------------------------
# Telomeric motif patterns
# ---------------------------------------------------------------------------
PATTERNS = [
    re.compile(r"C{2,4}T{1,2}A{1,3}", re.IGNORECASE),  # e.g. CCCTAA
    re.compile(r"T{1,3}A{1,2}G{2,4}", re.IGNORECASE),  # e.g. TTAGGG
]


def count_telomere_motifs(seq: str) -> int:
    total = 0
    for pat in PATTERNS:
        total += len(pat.findall(seq))
    return total


def sliding_window_counts(seq, window: int, step: int):
    seqlen = len(seq)
    for start in range(0, seqlen, step):
        end = min(start + window, seqlen)
        if end - start < 1:
            continue
        subseq = str(seq[start:end])
        yield start, end, count_telomere_motifs(subseq)


def plot_contig(name: str, plot_x: list, plot_y: list, outdir: str) -> str:
    fig, ax = plt.subplots(figsize=(12, 4))
    ax.plot(plot_x, plot_y, marker="o", linestyle="-", linewidth=0.8,
            markersize=2, color="steelblue")
    ax.set_xlabel("Position on contig (Mb)", fontsize=11)
    ax.set_ylabel("Telomere motif density\n(motifs per kb)", fontsize=11)
    ax.set_title(f"Telomeric motif density — {name}", fontsize=12)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    png_path = os.path.join(outdir, f"{name}.png")
    fig.savefig(png_path, dpi=300)
    plt.close(fig)
    return png_path


def main():
    parser = argparse.ArgumentParser(
        description="Compute telomeric motif density along genome contigs."
    )
    parser.add_argument("-i", "--fasta",    required=True,
                        help="Input genome FASTA (can be .fa, .fasta, .fa.gz)")
    parser.add_argument("-w", "--window",   type=int, default=10000,
                        help="Sliding window size in bp (default: 10000)")
    parser.add_argument("-s", "--step",     type=int, default=1000,
                        help="Step size in bp (default: 1000)")
    parser.add_argument("-o", "--out-tsv",  default="telomere_density.tsv",
                        help="Output TSV path")
    parser.add_argument("--outdir",         default=".",
                        help="Output directory for PNG plots")
    parser.add_argument("--min-contig",     type=int, default=0,
                        help="Skip contigs shorter than this (bp). Default: 0")
    args = parser.parse_args()

    # Validate input
    if not os.path.isfile(args.fasta):
        sys.exit(f"ERROR: FASTA not found: {args.fasta}")

    os.makedirs(args.outdir, exist_ok=True)

    contigs_processed = 0
    contigs_skipped   = 0

    with open(args.out_tsv, "w") as out:
        out.write("contig\tstart\tend\tlength_bp\tmotif_count\tmotifs_per_kb\n")

        for record in SeqIO.parse(args.fasta, "fasta"):
            name   = record.id
            seq    = record.seq
            seqlen = len(seq)

            if seqlen < args.min_contig:
                print(f"  Skipping {name} ({seqlen:,} bp < --min-contig {args.min_contig:,})",
                      file=sys.stderr)
                contigs_skipped += 1
                continue

            print(f"  Processing {name} ({seqlen:,} bp)...", file=sys.stderr)

            plot_x, plot_y = [], []

            for start, end, count in sliding_window_counts(seq, args.window, args.step):
                length_bp = end - start
                density = count / (length_bp / 1000.0) if length_bp > 0 else 0.0
                out.write(f"{name}\t{start}\t{end}\t{length_bp}\t{count}\t{density:.4f}\n")
                plot_x.append((start + end) / 2.0 / 1e6)
                plot_y.append(density)

            if plot_x:
                png = plot_contig(name, plot_x, plot_y, args.outdir)
                print(f"    → plot saved: {png}", file=sys.stderr)

            contigs_processed += 1

    print(f"\nDone. Processed {contigs_processed} contigs "
          f"({contigs_skipped} skipped). TSV: {args.out_tsv}", file=sys.stderr)


if __name__ == "__main__":
    main()
