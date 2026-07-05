#!/usr/bin/env python3
"""
Post-hoc data corrections for the MSA_stress conference figures.

Fixes three data-integrity bugs found in the HPC ('used_scripts') outputs:
  1. N50 in genome_stats_summary.tsv was garbage for ~7/12 isolates
     -> recompute directly from the assembly FASTAs.
  2. correlation_data.tsv columns were mislabelled/shifted (gh_count held the
     CAzyme %, ce_count was dropped, total_proteins masqueraded as total_cazymes)
     -> rebuild cleanly from cazyme_summary.tsv + pathogenicity_summary.tsv and
        recompute Pearson/Spearman correlations.
  3. effector_expansion_summary.tsv collapsed to one junk row (species split on
     the space in "F. xxx") -> rebuild per-species from effector_counts.tsv.

Also adds isolate+species columns to accessory_summary.tsv so Fig4b can label
properly. (NOTE: the accessory *values* remain suspect — see the audit report.)

Originals are backed up with a .preaudit suffix. Nothing is deleted.
"""
import sys, shutil
from pathlib import Path
import pandas as pd
import numpy as np
from scipy import stats

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "/home/maxclaude/MSA_2026/MSA_stress/conference_figs")

def backup(p: Path):
    b = p.with_suffix(p.suffix + ".preaudit")
    if p.exists() and not b.exists():
        shutil.copy2(p, b)
        print(f"  backed up {p.name} -> {b.name}")

def load(p):
    return pd.read_csv(p, sep="\t", dtype=str, engine="python")

# ---------------------------------------------------------------------------
# 1. Recompute N50 from the genome FASTAs
# ---------------------------------------------------------------------------
def contig_lengths(fasta: Path):
    lengths, cur = [], 0
    with open(fasta) as fh:
        for line in fh:
            if line.startswith(">"):
                if cur:
                    lengths.append(cur)
                cur = 0
            else:
                cur += len(line.strip())
    if cur:
        lengths.append(cur)
    return lengths

def n50(lengths):
    lengths = sorted(lengths, reverse=True)
    total = sum(lengths)
    half, run = total / 2.0, 0
    for L in lengths:
        run += L
        if run >= half:
            return L
    return 0

def fix_n50():
    gs_path = ROOT / "01_genome_stats/genome_stats_summary.tsv"
    gdir = ROOT / "00_input/genomes"
    print("[1] Recomputing N50 from assemblies...")
    gs = load(gs_path)
    backup(gs_path)
    new_n50, new_scaf, new_size = {}, {}, {}
    for samp in gs["sample"]:
        fa = gdir / f"{samp}.fasta"
        if not fa.exists():
            print(f"  WARN: {fa.name} missing, leaving N50 as-is for sample {samp}")
            continue
        L = contig_lengths(fa)
        new_n50[samp] = n50(L)
        new_scaf[samp] = len(L)
        new_size[samp] = sum(L)
    old = dict(zip(gs["sample"], gs["n50_bp"]))
    gs["n50_bp"] = gs["sample"].map(lambda s: new_n50.get(s, gs.loc[gs["sample"] == s, "n50_bp"].iloc[0]))
    # sanity: also refresh scaffold count & size (should already match)
    gs["num_scaffolds"] = gs["sample"].map(lambda s: new_scaf.get(s, gs.loc[gs["sample"] == s, "num_scaffolds"].iloc[0]))
    gs["genome_size_bp"] = gs["sample"].map(lambda s: new_size.get(s, gs.loc[gs["sample"] == s, "genome_size_bp"].iloc[0]))
    gs.to_csv(gs_path, sep="\t", index=False)
    print("  sample  old_N50 -> new_N50")
    for s in gs["sample"]:
        print(f"    {s:>2}   {old.get(s):>10} -> {new_n50.get(s):>10,}")
    return gs

# ---------------------------------------------------------------------------
# 2. Rebuild correlation data + correlations
# ---------------------------------------------------------------------------
def fix_correlation():
    print("[2] Rebuilding correlation_data.tsv + correlations...")
    caz = load(ROOT / "05_cazyme/cazyme_summary.tsv")
    path = load(ROOT / "06_phenotype/pathogenicity_summary.tsv")
    num_cols = ["total_proteins", "total_cazymes", "cazyme_percent",
                "gh_count", "gt_count", "pl_count", "ce_count"]
    for c in num_cols:
        caz[c] = pd.to_numeric(caz[c], errors="coerce")
    path["virulence_score"] = pd.to_numeric(path["virulence_score"], errors="coerce")

    merged = caz.merge(path[["sample", "virulence_score"]], on="sample", how="left")
    cols = ["sample", "isolate", "species", "total_cazymes", "gh_count",
            "gt_count", "pl_count", "ce_count", "cazyme_percent", "virulence_score"]
    corr_data = merged[cols].copy()

    cd_path = ROOT / "07_correlation/correlation_data.tsv"
    backup(cd_path)
    corr_data.to_csv(cd_path, sep="\t", index=False)

    # correlations vs virulence
    variables = ["total_cazymes", "gh_count", "gt_count", "pl_count",
                 "ce_count", "cazyme_percent"]
    rows = []
    v = corr_data["virulence_score"].astype(float)
    for var in variables:
        x = corr_data[var].astype(float)
        pr, pp = stats.pearsonr(x, v)
        sr, sp = stats.spearmanr(x, v)
        rows.append([var, "Pearson",  f"{pr:.4f}", f"{pp:.4e}", "yes" if pp < 0.05 else "no"])
        rows.append([var, "Spearman", f"{sr:.4f}", f"{sp:.4e}", "yes" if sp < 0.05 else "no"])
    summary = pd.DataFrame(rows, columns=["variable", "correlation_type",
                                          "r_value", "p_value", "significant"])
    cs_path = ROOT / "07_correlation/correlation_summary.tsv"
    backup(cs_path)
    summary.to_csv(cs_path, sep="\t", index=False)
    print("  variable        Pearson_r   p")
    for _, r in summary[summary.correlation_type == "Pearson"].iterrows():
        print(f"    {r.variable:<14} {r.r_value:>8}  {r.p_value}")
    return corr_data

# ---------------------------------------------------------------------------
# 3. Rebuild effector expansion summary (per species)
# ---------------------------------------------------------------------------
def fix_effector_expansion():
    print("[3] Rebuilding effector_expansion_summary.tsv...")
    eff = load(ROOT / "04_effector_analysis/effector_counts.tsv")
    eff["num_effectors"] = pd.to_numeric(eff["num_effectors"], errors="coerce")
    g = eff.groupby("species")["num_effectors"]
    out = pd.DataFrame({
        "mean_effectors": g.mean().round(2),
        "std_effectors":  g.std(ddof=0).round(2).fillna(0.0),
        "min":            g.min().astype(int),
        "max":            g.max().astype(int),
        "n_isolates":     g.size().astype(int),
    })
    out["expansion_index"] = (out["max"] / out["min"]).round(3)
    out = out.reset_index()
    ex_path = ROOT / "04_effector_analysis/effector_expansion_summary.tsv"
    backup(ex_path)
    out.to_csv(ex_path, sep="\t", index=False)
    print(out.to_string(index=False))
    return out

# ---------------------------------------------------------------------------
# 4. Label accessory_summary (values still suspect — see report)
# ---------------------------------------------------------------------------
def label_accessory():
    print("[4] Adding isolate/species labels to accessory_summary.tsv...")
    acc = load(ROOT / "02_accessory_genome/accessory_summary.tsv")
    bar = load(ROOT / "barlist.tsv")[["sample", "isolate", "species"]]
    if "isolate" in acc.columns:
        print("  already labelled; skipping")
        return acc
    acc = acc.merge(bar, on="sample", how="left")
    front = ["sample", "isolate", "species"]
    acc = acc[front + [c for c in acc.columns if c not in front]]
    ap = ROOT / "02_accessory_genome/accessory_summary.tsv"
    backup(ap)
    acc.to_csv(ap, sep="\t", index=False)
    neg = acc[pd.to_numeric(acc["accessory_genes"], errors="coerce") < 0]
    if not neg.empty:
        print(f"  WARNING: {len(neg)} isolate(s) have NEGATIVE accessory counts "
              f"(sample {list(neg['sample'])}) — accessory analysis is unreliable.")
    return acc

if __name__ == "__main__":
    print(f"=== Correcting data under {ROOT} ===")
    fix_n50()
    fix_correlation()
    fix_effector_expansion()
    label_accessory()
    print("=== Done. Originals preserved as *.preaudit ===")
