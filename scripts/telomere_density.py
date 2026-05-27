#!/usr/bin/env python3
import argparse
import re
import os

from Bio import SeqIO
import matplotlib.pyplot as plt

# Telomeric motifs as regex patterns
PATTERNS = [
    re.compile(r"C{2,4}T{1,2}A{1,3}", re.IGNORECASE),
    re.compile(r"T{1,3}A{1,2}G{2,4}", re.IGNORECASE),
]

def count_telomere_motifs(seq):
    total = 0
    for pat in PATTERNS:
        total += len(pat.findall(seq))
    return total

def sliding_window_counts(seq, window, step):
    seqlen = len(seq)
    for start in range(0, seqlen, step):
        end = min(start + window, seqlen)
        if end - start < 1:
            continue
        subseq = seq[start:end]
        c = count_telomere_motifs(str(subseq))
        yield start, end, c

def main():
    parser = argparse.ArgumentParser(
        description="Compute telomeric motif density along contigs."
    )
    parser.add_argument("-i", "--fasta", required=True, help="Input genome FASTA")
    parser.add_argument("-w", "--window", type=int, default=10000)
    parser.add_argument("-s", "--step", type=int, default=1000)
    parser.add_argument(
        "-o", "--out-tsv", default="telomere_density.tsv",
        help="Output TSV with motif density per window"
    )
    parser.add_argument(
        "--outdir", default=".",
        help="Directory to write PNG plots (one per contig)"
    )
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    # Open TSV
    out = open(args.out_tsv, "w")
    out.write("contig\tstart\tend\tlength_bp\tmotif_count\tmotifs_per_kb\n")

    # For each contig, collect plotting data
    for record in SeqIO.parse(args.fasta, "fasta"):
        name = record.id
        seq = record.seq

        plot_x = []
        plot_y = []

        for start, end, count in sliding_window_counts(seq, args.window, args.step):
            length_bp = end - start
            density = count / (length_bp / 1000.0) if length_bp > 0 else 0.0

            out.write(
                f"{name}\t{start}\t{end}\t{length_bp}\t{count}\t{density:.4f}\n"
            )

            mid = (start + end) / 2.0
            plot_x.append(mid / 1e6)
            plot_y.append(density)

        # Plot this contig
        if plot_x:
            plt.figure(figsize=(10, 4))
            plt.plot(plot_x, plot_y, marker="o", linestyle="-", linewidth=1)
            plt.xlabel("Position on contig (Mb)")
            plt.ylabel("Telomere motif density (motifs per kb)")
            plt.title(f"Telomeric motif density — {name}")
            plt.tight_layout()

            png_path = os.path.join(args.outdir, f"{name}.png")
            plt.savefig(png_path, dpi=300)
            plt.close()

    out.close()

if __name__ == "__main__":
    main()
