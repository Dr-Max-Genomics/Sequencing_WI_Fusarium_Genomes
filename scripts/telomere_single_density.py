#!/usr/bin/env python3
import argparse
import re

from Bio import SeqIO
import matplotlib.pyplot as plt

# Telomeric motifs as regex patterns
PATTERNS = [
    re.compile(r"C{2,4}T{1,2}A{1,3}", re.IGNORECASE),
    re.compile(r"T{1,3}A{1,2}G{2,4}", re.IGNORECASE),
]

def count_telomere_motifs(seq):
    """Count total matches of all telomeric motifs in a sequence string."""
    total = 0
    for pat in PATTERNS:
        total += len(pat.findall(seq))
    return total

def sliding_window_counts(seq, window, step):
    """Yield (start, end, count) for each window along the sequence."""
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
    parser.add_argument(
        "-i", "--fasta", required=True,
        help="Input genome FASTA"
    )
    parser.add_argument(
        "-w", "--window", type=int, default=10000,
        help="Sliding window size (bp) [default: 10000]"
    )
    parser.add_argument(
        "-s", "--step", type=int, default=1000,
        help="Step size between windows (bp) [default: 1000]"
    )
    parser.add_argument(
        "-o", "--out-tsv", default="telomere_density.tsv",
        help="Output TSV with motif density per window"
    )
    parser.add_argument(
        "--plot-contig", default=None,
        help="Optional contig name to plot motif density for"
    )
    parser.add_argument(
        "--plot-png", default="telomere_density.png",
        help="Output plot filename if --plot-contig is set"
    )
    args = parser.parse_args()

    # Open TSV
    out = open(args.out_tsv, "w")
    out.write("contig\tstart\tend\tlength_bp\tmotif_count\tmotifs_per_kb\n")

    # For plotting a single contig if requested
    plot_x = []
    plot_y = []

    for record in SeqIO.parse(args.fasta, "fasta"):
        name = record.id
        seq = record.seq
        seqlen = len(seq)

        for start, end, count in sliding_window_counts(seq, args.window, args.step):
            length_bp = end - start
            density = count / (length_bp / 1000.0) if length_bp > 0 else 0.0
            out.write(
                f"{name}\t{start}\t{end}\t{length_bp}\t{count}\t{density:.4f}\n"
            )
            if args.plot_contig and name == args.plot_contig:
                # x = mid-point of window in Mb, y = motifs per kb
                mid = (start + end) / 2.0
                plot_x.append(mid / 1e6)
                plot_y.append(density)

    out.close()

    # Plot if requested
    if args.plot_contig:
        if not plot_x:
            print(f"No windows found for contig {args.plot_contig}")
            return
        plt.figure(figsize=(10, 4))
        plt.plot(plot_x, plot_y, marker="o", linestyle="-", linewidth=1)
        plt.xlabel("Position on contig (Mb)")
        plt.ylabel("Telomere motif density (motifs per kb)")
        plt.title(f"Telomeric motif density along {args.plot_contig}")
        plt.tight_layout()
        plt.savefig(args.plot_png, dpi=300)
        print(f"Saved plot to {args.plot_png}")

if __name__ == "__main__":
    main()
