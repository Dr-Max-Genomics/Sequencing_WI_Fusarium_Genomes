#!/usr/bin/env python3
"""
CONFERENCE FIGURES PIPELINE: Publication-Ready Figure Generation (final)

Generates 5 figure groups:
  1. Heat Stress Growth
  2. Cold Stress Growth
  3. Optimum Temperature Growth
  4. Barley Pathogenicity
  5. Genome Analyses (4a-4d):
     4a. Structural Variation Overview (Isolate-only labels; FFSC/FSAMSC colors; GC colored by species)
     4b. Macro-structural & Accessory Gene Variation
     4c. Lineage-specific Chromosomal Fissions
     4d. Effector Gene Expansions
  6. CAzyme Profiles & Virulence Correlation

Usage:
  python3 scripts/08_generate_figures.py /path/to/analysis_root

Output: PNG/PDF files in 08_figures/
"""

import sys
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from matplotlib.ticker import FixedLocator

# Set style
sns.set_style("whitegrid")
sns.set_palette("husl")
plt.rcParams['figure.dpi'] = 300
plt.rcParams['font.size'] = 10
plt.rcParams['font.family'] = 'sans-serif'

# --- Helper utilities ---
ROTATION_ANGLE = 45

# === MASTER ORDER & COMPLEX/SPECIES MAPPING (from provided master source) ===
ORDER_12_ISOLATES = [
    "F-22-24",
    "F-22-6",
    "F-Arl-23.2b",
    "F-Arl-23.6",
    "F-23-8.10",
    "F-23-2.3",
    "F-22-214.4",
    "F-23-1.3",
    "F-23-7.2",
    "F-23-8.6",
    "F-23.10",
    "F-22-12a",
]

SAMPLE_TO_ISOLATE = {
    1: "F-22-24",
    2: "F-22-6",
    3: "F-Arl-23.2b",
    4: "F-Arl-23.6",
    5: "F-23-8.10",
    6: "F-23-2.3",
    7: "F-22-214.4",
    8: "F-23-1.3",
    9: "F-23-7.2",
    10: "F-23-8.6",
    11: "F-23.10",
    12: "F-22-12a",
}

ISOLATE_TO_COMPLEX = {
    # First 6: FFSC
    "F-22-24": "FFSC",
    "F-22-6": "FFSC",
    "F-Arl-23.2b": "FFSC",
    "F-Arl-23.6": "FFSC",
    "F-23-8.10": "FFSC",
    "F-23-2.3": "FFSC",
    # Second 6: FSAMSC
    "F-22-214.4": "FSAMSC",
    "F-23-1.3": "FSAMSC",
    "F-23-7.2": "FSAMSC",
    "F-23-8.6": "FSAMSC",
    "F-23.10": "FSAMSC",
    "F-22-12a": "FSAMSC",
}

SAMPLE_TO_COMPLEX = {i: ("FFSC" if i <= 6 else "FSAMSC") for i in range(1, 13)}

# Species mapping for GC content coloring
ISOLATE_TO_SPECIES = {
    "F-22-24": "F. fujikuroi",
    "F-22-6": "F. proliferatum",
    "F-Arl-23.2b": "F. proliferatum",
    "F-Arl-23.6": "F. proliferatum",
    "F-23-8.10": "F. proliferatum",
    "F-23-2.3": "F. subglutinans",
    "F-22-214.4": "F. graminearum",
    "F-23-1.3": "F. graminearum",
    "F-23-7.2": "F. graminearum",
    "F-23-8.6": "F. graminearum",
    "F-23.10": "F. graminearum",
    "F-22-12a": "F. sporotrichioides",
}

# Color choices (adjust as needed)
COLORS = {
    "FFSC": "#4C78A8",   # blue
    "FSAMSC": "#E45756", # red
}

def get_isolate_col(df):
    """
    Return the column name to use for isolate identifiers.
    Prefers 'isolate', falls back to 'sample', otherwise None.
    """
    for col in ['isolate', 'sample']:
        if col in df.columns:
            return col
    return None

def get_species_col(df):
    """Return the column name for species if present, else None."""
    for col in ['species', 'Species']:
        if col in df.columns:
            return col
    return None

def build_isolate_label(isolate, species=None):
    """
    Two-line label:
      Line 1: isolate name (e.g., F-22-24)
      Line 2: species in parentheses, italicized, e.g., (F. fujikuroi)

    Uses mathtext to italicize only the species text inside parentheses.
    """
    iso = str(isolate)
    if species and str(species).strip():
        sp = str(species).strip()
        sp_fmt = "$(" + r"\it{" + sp + "}" + ")$"
        return f"{iso}\n{sp_fmt}"
    else:
        return iso

def make_label_map(df, isolate_col, species_col):
    """Build mapping: isolate identifier -> formatted two-line label."""
    label_map = {}
    cols = [c for c in [isolate_col, species_col] if c]
    if not cols:
        return label_map
    for _, r in df[cols].drop_duplicates().iterrows():
        iso = r[isolate_col]
        sp = r[species_col] if species_col else None
        label_map[str(iso)] = build_isolate_label(iso, sp)
    return label_map

def get_isolate_order(df, isolate_col, limit_to_12=True):
    """
    Return a stable order of isolates. If more than 12 are present and limit_to_12=True,
    truncate to the first 12 alphabetically.
    """
    order = sorted(map(str, df[isolate_col].dropna().unique()))
    if limit_to_12 and len(order) > 12:
        print(f"INFO: Found {len(order)} isolates; restricting to first 12 for figure clarity.")
        order = order[:12]
    return order

def apply_categorical_ticklabels(ax, labels, rotation=ROTATION_ANGLE):
    """
    Avoids warnings by setting a FixedLocator before assigning tick labels.
    Assumes categorical plots map categories to positions [0..len(labels)-1].
    """
    ax.xaxis.set_major_locator(FixedLocator(range(len(labels))))
    ax.set_xticklabels(labels, rotation=rotation, ha='right')

def load_data(analysis_root):
    """Load all analysis outputs"""
    data = {}
    
    # Load growth rate data
    try:
        data['growth_heat_cold'] = pd.read_csv(
            f"{analysis_root}/06_phenotype/growth_rates_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: growth_rates_summary.tsv not found")
    
    try:
        data['growth_optimum'] = pd.read_csv(
            f"{analysis_root}/06_phenotype/growth_rates_optimum_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: growth_rates_optimum_summary.tsv not found")
    
    # Load pathogenicity data
    try:
        data['pathogenicity'] = pd.read_csv(
            f"{analysis_root}/06_phenotype/pathogenicity_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: pathogenicity_summary.tsv not found")
    
    # Load genome stats
    try:
        data['genome_stats'] = pd.read_csv(
            f"{analysis_root}/01_genome_stats/genome_stats_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: genome_stats_summary.tsv not found")
    
    # Load accessory genome data
    try:
        data['accessory_summary'] = pd.read_csv(
            f"{analysis_root}/02_accessory_genome/accessory_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: accessory_summary.tsv not found")
    
    # Load synteny data
    try:
        data['synteny_pairwise'] = pd.read_csv(
            f"{analysis_root}/03_synteny/synteny_pairwise.tsv",
            sep='\t'
        )
    except:
        print("WARNING: synteny_pairwise.tsv not found")
    
    # Load effector data
    try:
        data['effector_counts'] = pd.read_csv(
            f"{analysis_root}/04_effector_analysis/effector_counts.tsv",
            sep='\t'
        )
    except:
        print("WARNING: effector_counts.tsv not found")
    
    try:
        data['effector_expansion'] = pd.read_csv(
            f"{analysis_root}/04_effector_analysis/effector_expansion_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: effector_expansion_summary.tsv not found")
    
    # Load CAzyme data
    try:
        data['cazyme_summary'] = pd.read_csv(
            f"{analysis_root}/05_cazyme/cazyme_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: cazyme_summary.tsv not found")
    
    # Load correlation data
    try:
        data['correlation_summary'] = pd.read_csv(
            f"{analysis_root}/07_correlation/correlation_summary.tsv",
            sep='\t'
        )
    except:
        print("WARNING: correlation_summary.tsv not found")
    
    try:
        data['correlation_data'] = pd.read_csv(
            f"{analysis_root}/07_correlation/correlation_data.tsv",
            sep='\t'
        )
    except:
        print("WARNING: correlation_data.tsv not found")
    
    return data

def figure_1_heat_stress(data, output_dir):
    """Fig 1: Heat Stress Growth (isolate-level)"""
    if 'growth_heat_cold' not in data:
        print("Skipping Fig 1: heat stress data not available")
        return
    
    df = data['growth_heat_cold']
    heat_data = df[df['condition'] == 'heat']
    if heat_data.empty:
        print("Skipping Fig 1: no heat stress data")
        return
    
    isolate_col = get_isolate_col(heat_data) or 'species'
    species_col = get_species_col(heat_data)
    isolate_order = get_isolate_order(heat_data, isolate_col, limit_to_12=True)
    heat_data = heat_data[heat_data[isolate_col].astype(str).isin(isolate_order)]
    label_map = make_label_map(heat_data, isolate_col, species_col)
    tick_texts = [label_map.get(t, t) for t in isolate_order]

    fig, ax = plt.subplots(figsize=(10, 6))
    sns.barplot(
        data=heat_data,
        x=isolate_col,
        y='mean_growth_rate',
        order=isolate_order,
        ax=ax,
        errorbar='sd'
    )
    apply_categorical_ticklabels(ax, tick_texts)

    ax.set_xlabel('Isolate', fontsize=12, fontweight='bold')
    ax.set_ylabel('Growth Rate (mm/day)', fontsize=12, fontweight='bold')
    ax.set_title('Heat Stress (Growth Rate)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    fig.savefig(f"{output_dir}/Fig1_Heat_Stress.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig1_Heat_Stress.png")
    plt.close()

def figure_2_cold_stress(data, output_dir):
    """Fig 2: Cold Stress Growth (isolate-level)"""
    if 'growth_heat_cold' not in data:
        return
    
    df = data['growth_heat_cold']
    cold_data = df[df['condition'] == 'cold']
    if cold_data.empty:
        print("Skipping Fig 2: no cold stress data")
        return
    
    isolate_col = get_isolate_col(cold_data) or 'species'
    species_col = get_species_col(cold_data)
    isolate_order = get_isolate_order(cold_data, isolate_col, limit_to_12=True)
    cold_data = cold_data[cold_data[isolate_col].astype(str).isin(isolate_order)]
    label_map = make_label_map(cold_data, isolate_col, species_col)
    tick_texts = [label_map.get(t, t) for t in isolate_order]

    fig, ax = plt.subplots(figsize=(10, 6))
    sns.barplot(
        data=cold_data,
        x=isolate_col,
        y='mean_growth_rate',
        order=isolate_order,
        ax=ax,
        errorbar='sd'
    )
    apply_categorical_ticklabels(ax, tick_texts)

    ax.set_xlabel('Isolate', fontsize=12, fontweight='bold')
    ax.set_ylabel('Growth Rate (mm/day)', fontsize=12, fontweight='bold')
    ax.set_title('Cold Stress (Growth Rate)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    fig.savefig(f"{output_dir}/Fig2_Cold_Stress.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig2_Cold_Stress.png")
    plt.close()

def figure_3_optimum(data, output_dir):
    """Fig 3: Optimum Temperature Growth (isolate-level)"""
    if 'growth_optimum' not in data:
        return
    
    df = data['growth_optimum']
    isolate_col = get_isolate_col(df) or 'species'
    species_col = get_species_col(df)
    isolate_order = get_isolate_order(df, isolate_col, limit_to_12=True)
    df = df[df[isolate_col].astype(str).isin(isolate_order)]
    label_map = make_label_map(df, isolate_col, species_col)
    tick_texts = [label_map.get(t, t) for t in isolate_order]

    fig, ax = plt.subplots(figsize=(10, 6))
    sns.barplot(
        data=df,
        x=isolate_col,
        y='mean_diameter_mm',
        order=isolate_order,
        ax=ax,
        errorbar='sd'
    )
    apply_categorical_ticklabels(ax, tick_texts)

    ax.set_xlabel('Isolate', fontsize=12, fontweight='bold')
    ax.set_ylabel('Colony Diameter (mm)', fontsize=12, fontweight='bold')
    ax.set_title('Optimum Temperature (7-day Colony Diameter)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    fig.savefig(f"{output_dir}/Fig3_Optimum_Growth.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig3_Optimum_Growth.png")
    plt.close()

def figure_4_barley_pathogenicity(data, output_dir):
    """Fig 4: Barley Seedling Pathogenicity (unchanged; isolate-level)"""
    if 'pathogenicity' not in data:
        return
    
    df = data['pathogenicity']
    fig, ax = plt.subplots(figsize=(11, 6))
    
    df_sorted = df.sort_values('virulence_score', ascending=False)
    colors = df_sorted['infection_severity'].map({
        'high': '#d62728',
        'moderate': '#ff7f0e',
        'low': '#2ca02c'
    })
    
    ax.bar(range(len(df_sorted)), df_sorted['virulence_score'], 
           color=colors, edgecolor='black', linewidth=1)
    
    ax.errorbar(range(len(df_sorted)), df_sorted['virulence_score'],
                yerr=df_sorted['sem_virulence'],
                fmt='none', color='black', capsize=3, alpha=0.5)
    
    ax.set_xticks(range(len(df_sorted)))
    ax.set_xticklabels(df_sorted['isolate'], rotation=ROTATION_ANGLE, ha='right')
    ax.set_xlabel('Isolate', fontsize=12, fontweight='bold')
    ax.set_ylabel('Virulence Score', fontsize=12, fontweight='bold')
    ax.set_title('Barley Seedling Pathogenicity (Virulence)', fontsize=14, fontweight='bold')
    
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor='#d62728', edgecolor='black', label='High'),
        Patch(facecolor='#ff7f0e', edgecolor='black', label='Moderate'),
        Patch(facecolor='#2ca02c', edgecolor='black', label='Low')
    ]
    ax.legend(handles=legend_elements, title='Severity', loc='upper right')
    
    plt.tight_layout()
    fig.savefig(f"{output_dir}/Fig4_Barley_Pathogenicity.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig4_Barley_Pathogenicity.png")
    plt.close()

def figure_4a_structural_variation(data, output_dir):
    """
    Fig 4a: Structural Variation Overview (Isolate-only labels; FFSC/FSAMSC colors; GC colored by species)
    - Retains 4 subplots: Genome Size, GC Content, # Scaffolds, N50
    - X-axis shows *only isolate names* (slanted), no species in labels
    - First 6 isolates (FFSC) one color; second 6 isolates (FSAMSC) another color for bars
    - GC Content points colored by *species* (consistent with earlier species color schema)
    """
    if 'genome_stats' not in data:
        return
    
    df = data['genome_stats'].copy()
    isolate_col = get_isolate_col(df) or 'sample'  # prefer 'isolate', fall back to numeric 'sample'

    # --- Build ordered categories and tick labels (isolate names only, slanted) ---
    if isolate_col == 'isolate':
        iso_order = [iso for iso in ORDER_12_ISOLATES if iso in df[isolate_col].astype(str).unique()]
        tick_labels = iso_order[:]  # isolate names only
        group_for_iso = {iso: ISOLATE_TO_COMPLEX.get(iso, None) for iso in iso_order}
        bar_colors = [COLORS.get(group_for_iso[iso], '#888888') for iso in iso_order]
        # Align df to only the ordered isolates, and compute x positions
        df = df[df[isolate_col].astype(str).isin(iso_order)].copy()
        df['_xpos'] = df[isolate_col].astype(str).apply(lambda x: iso_order.index(x))
        # Species per isolate (for GC coloring)
        df['_species_for_gc'] = df[isolate_col].astype(str).map(ISOLATE_TO_SPECIES)
    else:
        # isolate_col == 'sample' (numeric)
        df['sample'] = pd.to_numeric(df['sample'], errors='coerce').astype('Int64')
        present = [int(s) for s in df['sample'].dropna().unique()]
        iso_order_samples = [s for s in range(1, 13) if s in present]
        tick_labels = [SAMPLE_TO_ISOLATE[s] for s in iso_order_samples]  # isolate names only
        group_for_sample = {s: SAMPLE_TO_COMPLEX.get(s, None) for s in iso_order_samples}
        bar_colors = [COLORS.get(group_for_sample[s], '#888888') for s in iso_order_samples]
        df = df[df['sample'].isin(iso_order_samples)].copy()
        df['_xpos'] = df['sample'].astype(int).apply(lambda s: iso_order_samples.index(s))
        # Species per sample (map via isolate name)
        df['_species_for_gc'] = df['sample'].astype(int).map(lambda s: ISOLATE_TO_SPECIES.get(SAMPLE_TO_ISOLATE[s]))

    # Helper to extract values aligned to positions
    def values_by_xpos(colname, convert_numeric=True):
        vals = df[['_xpos', colname]].dropna()
        if convert_numeric:
            vals[colname] = pd.to_numeric(vals[colname], errors='coerce')
        # Initialize with NaN to keep alignment length equal to tick_labels
        out = [np.nan] * len(tick_labels)
        for _, r in vals.iterrows():
            out[int(r['_xpos'])] = r[colname]
        return out

    # Prepare figure (2x2: Genome Size, GC Content, Scaffolds, N50)
    fig, axes = plt.subplots(2, 2, figsize=(14, 8))
    xpos = np.arange(len(tick_labels))

    # --- [0,0] Genome Size (bar, colored by complex) ---
    ax = axes[0, 0]
    genome_sizes = values_by_xpos('genome_size_bp', convert_numeric=True)
    gs_plot = [0 if pd.isna(v) else v for v in genome_sizes]
    ax.bar(xpos, gs_plot, color=bar_colors, edgecolor='black', linewidth=0.8)
    ax.set_ylabel('Genome Size (bp)', fontweight='bold')
    ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_title('Genome Size', fontweight='bold')
    ax.set_xticks(xpos)
    apply_categorical_ticklabels(ax, tick_labels)

    # --- [0,1] GC Content (scatter, colored by species; isolate-only labels) ---
    ax = axes[0, 1]
    gc_vals = values_by_xpos('gc_percent', convert_numeric=True)
    # Build a plotting DataFrame to let seaborn handle species hue consistently
    gc_plot_df = pd.DataFrame({
        'xpos': [i for i, v in enumerate(gc_vals) if not pd.isna(v)],
        'gc_percent': [v for v in gc_vals if not pd.isna(v)],
    })
    # Map species to the same order as tick labels for consistent coloring
    gc_plot_df['species'] = gc_plot_df['xpos'].map(lambda i: df.loc[df['_xpos'] == i, '_species_for_gc'].iloc[0] if not df.loc[df['_xpos'] == i, '_species_for_gc'].empty else None)
    # Use seaborn to color by species (consistent schema for unique species)
    sns.scatterplot(data=gc_plot_df, x='xpos', y='gc_percent', hue='species', s=100, ax=ax, legend=False)
    ax.set_ylabel('GC Content (%)', fontweight='bold')
    ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_title('GC Content', fontweight='bold')
    ax.set_xticks(xpos)
    apply_categorical_ticklabels(ax, tick_labels)

    # --- [1,0] Number of Scaffolds (bar, colored by complex) ---
    ax = axes[1, 0]
    num_scaff = values_by_xpos('num_scaffolds', convert_numeric=True)
    ns_plot = [0 if pd.isna(v) else v for v in num_scaff]
    ax.bar(xpos, ns_plot, color=bar_colors, edgecolor='black', linewidth=0.8)
    ax.set_ylabel('Number of Scaffolds', fontweight='bold')
    ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_title('Genomic Fragmentation', fontweight='bold')
    ax.set_xticks(xpos)
    apply_categorical_ticklabels(ax, tick_labels)

    # --- [1,1] N50 (bar, colored by complex) ---
    ax = axes[1, 1]
    n50_vals = values_by_xpos('n50_bp', convert_numeric=True) if 'n50_bp' in df.columns else [np.nan] * len(tick_labels)
    n50_plot = [0 if (pd.isna(v) or v is None) else v for v in n50_vals]
    ax.bar(xpos, n50_plot, color=bar_colors, edgecolor='black', linewidth=0.8)
    ax.set_ylabel('N50 (bp)', fontweight='bold')
    ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_title('N50 Value', fontweight='bold')
    ax.set_xticks(xpos)
    apply_categorical_ticklabels(ax, tick_labels)

    # Legend for complexes
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor=COLORS['FFSC'], edgecolor='black', label='FFSC'),
        Patch(facecolor=COLORS['FSAMSC'], edgecolor='black', label='FSAMSC'),
    ]
    axes[1, 1].legend(handles=legend_elements, title='Species Complex', loc='upper right')

    plt.suptitle('Structural Variation Overview', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    fig.savefig(f"{output_dir}/Fig4a_Structural_Variation.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig4a_Structural_Variation.png")
    plt.close()

def figure_4b_accessory_genes(data, output_dir):
    """Fig 4b: Macro-structural & Accessory Gene Variation — isolate labels formatted"""
    if 'accessory_summary' not in data:
        return
    
    df = data['accessory_summary']
    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    
    iso_col = get_isolate_col(df) or 'sample'
    sp_col = get_species_col(df)
    iso_order = get_isolate_order(df, iso_col, limit_to_12=True)
    df = df[df[iso_col].astype(str).isin(iso_order)].copy()
    label_map = make_label_map(df, iso_col, sp_col)
    tick_texts = [label_map.get(t, t) for t in iso_order]

    # Core vs accessory genes (bar)
    ax = axes[0]
    df_melted = df[[iso_col, 'core_genes', 'accessory_genes']].set_index(iso_col).stack().reset_index()
    df_melted.columns = ['sample', 'gene_type', 'count']
    sns.barplot(data=df_melted, x='sample', y='count', hue='gene_type', ax=ax, order=iso_order)
    ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_ylabel('Number of Genes', fontweight='bold')
    ax.set_title('Core vs Accessory Genes', fontweight='bold')
    apply_categorical_ticklabels(ax, tick_texts)

    # Gene count distribution (scatter) — map isolates to fixed positions
    ax = axes[1]
    iso_to_idx = {iso: i for i, iso in enumerate(iso_order)}
    x_pos = df[iso_col].astype(str).map(iso_to_idx)
    ax.scatter(x_pos, df['total_genes'], s=150, alpha=0.6, label='Total')
    ax.scatter(x_pos, df['core_genes'], s=100, alpha=0.6, label='Core')
    ax.scatter(x_pos, df['accessory_genes'], s=100, alpha=0.6, label='Accessory')
    ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_ylabel('Number of Genes', fontweight='bold')
    ax.set_title('Gene Count Distribution', fontweight='bold')
    ax.legend()
    apply_categorical_ticklabels(ax, tick_texts)
    
    plt.suptitle('Macro-structural & Accessory Gene Variation', fontsize=14, fontweight='bold', y=1.00)
    plt.tight_layout()
    fig.savefig(f"{output_dir}/Fig4b_Accessory_Genes.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig4b_Accessory_Genes.png")
    plt.close()

def figure_4c_lineage_fissions(data, output_dir):
    """Fig 4c: Lineage-specific Chromosomal Fissions (Synteny)"""
    if 'synteny_pairwise' not in data:
        return
    
    df = data['synteny_pairwise']
    for col in ["synteny_breaks", "mean_query_cov", "num_alignments"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Guard: the HPC synteny job produced no alignments (all minimap2 calls
    # failed on a bad output path). Emit a clearly-labelled placeholder instead
    # of a blank plot so the figure set is complete and self-documenting.
    if df.empty or 'synteny_breaks' not in df.columns or df['synteny_breaks'].dropna().empty:
        fig, ax = plt.subplots(figsize=(12, 6))
        ax.axis('off')
        ax.text(0.5, 0.62, 'Fig 4c — Lineage-specific Chromosomal Fissions',
                ha='center', va='center', fontsize=15, fontweight='bold')
        ax.text(0.5, 0.42,
                'PENDING RE-ANALYSIS: the synteny step produced no alignments\n'
                '(minimap2 output-path bug). Re-run 03_synteny with the corrected\n'
                'script, then regenerate this panel.',
                ha='center', va='center', fontsize=12, color='#b00020')
        fig.savefig(f"{output_dir}/Fig4c_Chromosomal_Fissions.png", dpi=300, bbox_inches='tight')
        print("⚠ Fig4c: synteny data empty — wrote placeholder (rerun required)")
        plt.close()
        return

    fig, axes = plt.subplots(1, 2, figsize=(14, 6))
    
    # Synteny breaks by species pair
    ax = axes[0]
    df_top = df.nlargest(12, 'synteny_breaks')
    species_pairs = df_top['query_species'] + ' vs ' + df_top['ref_species']
    sns.barplot(data=df_top, x=range(len(df_top)), y='synteny_breaks', ax=ax, palette='Set2')
    ax.set_xticks(range(len(df_top)))
    ax.set_xticklabels(species_pairs, rotation=ROTATION_ANGLE, ha='right')
    ax.set_xlabel('Species Pair', fontweight='bold')
    ax.set_ylabel('Number of Synteny Breaks', fontweight='bold')
    ax.set_title('Chromosomal Rearrangements (Top 12)', fontweight='bold')
    
    # Coverage vs Rearrangements
    ax = axes[1]
    sc = ax.scatter(df['mean_query_cov'], df['synteny_breaks'], 
               s=100, alpha=0.6, c=df['num_alignments'], cmap='viridis')
    ax.set_xlabel('Query Coverage (%)', fontweight='bold')
    ax.set_ylabel('Synteny Breaks', fontweight='bold')
    ax.set_title('Coverage vs Rearrangements', fontweight='bold')
    cbar = plt.colorbar(sc, ax=ax)
    cbar.set_label('Num Alignments', fontweight='bold')
    
    plt.suptitle('Lineage-specific Chromosomal Fissions', fontsize=14, fontweight='bold', y=1.00)
    plt.tight_layout()
    fig.savefig(f"{output_dir}/Fig4c_Chromosomal_Fissions.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig4c_Chromosomal_Fissions.png")
    plt.close()

def figure_4d_effector_expansions(data, output_dir):
    """Fig 4d: Effector Gene Expansions (robust labels; no seaborn palette warnings)"""
    if 'effector_counts' not in data:
        return
    
    df = data['effector_counts']
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # Total effectors per isolate (remove palette to avoid FutureWarning)
    ax = axes[0, 0]
    df_sorted = df.sort_values('num_effectors', ascending=False)
    sns.barplot(data=df_sorted, x='sample', y='num_effectors', ax=ax)
    ax.set_ylabel('Number of Effectors', fontweight='bold')
    ax.set_xlabel('')
    ax.set_title('Effector Count per Isolate', fontweight='bold')
    plt.setp(ax.get_xticklabels(), rotation=ROTATION_ANGLE, ha='right')
    
    # Effectors per Mb (remove palette to avoid FutureWarning)
    ax = axes[0, 1]
    df_sorted2 = df[df['proteins_per_mb'] != 'NA'].copy()
    if not df_sorted2.empty:
        df_sorted2['proteins_per_mb'] = pd.to_numeric(df_sorted2['proteins_per_mb'], errors='coerce')
        df_sorted2 = df_sorted2.sort_values('proteins_per_mb', ascending=False)
        sns.barplot(data=df_sorted2, x='sample', y='proteins_per_mb', ax=ax)
    ax.set_ylabel('Effectors per Mb', fontweight='bold')
    ax.set_xlabel('')
    ax.set_title('Effector Density', fontweight='bold')
    plt.setp(ax.get_xticklabels(), rotation=ROTATION_ANGLE, ha='right')
    
    # Expansion subplot (species if available; else isolate-level fallback)
    ax = axes[1, 0]
    if 'effector_expansion' in data:
        exp_df = data['effector_expansion'].copy()
        if 'species' in exp_df.columns:
            sns.barplot(data=exp_df, x='species', y='expansion_index', ax=ax)
            ax.set_ylabel('Expansion Index (Max/Min)', fontweight='bold')
            ax.set_xlabel('Species', fontweight='bold')
            ax.set_title('Intraspecific Effector Expansion', fontweight='bold')
            plt.setp(ax.get_xticklabels(), rotation=ROTATION_ANGLE, ha='right')
        else:
            iso_col = get_isolate_col(exp_df) or ('sample' if 'sample' in exp_df.columns else None)
            if iso_col and 'expansion_index' in exp_df.columns:
                sp_col = get_species_col(exp_df)
                iso_order = get_isolate_order(exp_df, iso_col, limit_to_12=True)
                exp_df = exp_df[exp_df[iso_col].astype(str).isin(iso_order)].copy()
                label_map = make_label_map(exp_df, iso_col, sp_col)
                tick_texts = [label_map.get(t, t) for t in iso_order]
                sns.barplot(data=exp_df, x=iso_col, y='expansion_index', ax=ax, order=iso_order)
                ax.set_ylabel('Expansion Index (Max/Min)', fontweight='bold')
                ax.set_xlabel('Isolate', fontweight='bold')
                ax.set_title('Effector Expansion (Isolate-level)', fontweight='bold')
                apply_categorical_ticklabels(ax, tick_texts)
            else:
                ax.text(0.5, 0.5, 'Expansion summary missing species/isolate columns',
                        ha='center', va='center', transform=ax.transAxes)
                ax.axis('off')
    else:
        ax.text(0.5, 0.5, 'No expansion summary available',
                ha='center', va='center', transform=ax.transAxes)
        ax.axis('off')
    
    # Boxplot by species (fallback to isolate if species missing)
    ax = axes[1, 1]
    if 'species' in df.columns:
        sns.boxplot(data=df, x='species', y='num_effectors', ax=ax)
        ax.set_xlabel('Species', fontweight='bold')
    else:
        iso_col = get_isolate_col(df) or 'sample'
        sns.boxplot(data=df, x=iso_col, y='num_effectors', ax=ax)
        ax.set_xlabel('Isolate', fontweight='bold')
    ax.set_ylabel('Number of Effectors', fontweight='bold')
    ax.set_title('Effector Distribution', fontweight='bold')
    plt.setp(ax.get_xticklabels(), rotation=ROTATION_ANGLE, ha='right')
    
    plt.suptitle('Effector Gene Expansions', fontsize=14, fontweight='bold', y=1.00)
    plt.tight_layout()
    fig.savefig(f"{output_dir}/Fig4d_Effector_Expansions.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig4d_Effector_Expansions.png")
    plt.close()

def figure_5_cazyme_virulence(data, output_dir):
    """Fig 5: CAzyme Profiles & Correlation with Virulence"""
    if 'cazyme_summary' not in data or 'correlation_data' not in data:
        return
    
    cazyme_df = data['cazyme_summary']
    corr_df = data['correlation_data']
    
    fig = plt.figure(figsize=(14, 10))
    gs = fig.add_gridspec(3, 2, hspace=0.3, wspace=0.3)
    
    # CAzyme family distribution
    ax1 = fig.add_subplot(gs[0, :])
    family_counts = {'GH': cazyme_df['gh_count'].sum(),
                     'GT': cazyme_df['gt_count'].sum(),
                     'PL': cazyme_df['pl_count'].sum(),
                     'CE': cazyme_df['ce_count'].sum()}
    
    ax1.bar(list(family_counts.keys()), list(family_counts.values()),
            color=['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728'])
    ax1.set_ylabel('Total Count', fontweight='bold')
    ax1.set_title('CAzyme Family Distribution Across All Isolates', fontweight='bold')
    
    # CAzyme count per isolate
    ax2 = fig.add_subplot(gs[1, 0])
    cazyme_sorted = cazyme_df.sort_values('total_cazymes', ascending=False)
    sns.barplot(data=cazyme_sorted, x='sample', y='total_cazymes', ax=ax2)
    ax2.set_ylabel('Total CAzymes', fontweight='bold')
    ax2.set_xlabel('')
    ax2.set_title('CAzyme Counts per Isolate', fontweight='bold')
    plt.setp(ax2.get_xticklabels(), rotation=ROTATION_ANGLE, ha='right')
    
    # CAzyme percent
    ax3 = fig.add_subplot(gs[1, 1])
    cazyme_pct = cazyme_df[cazyme_df['cazyme_percent'] != 'NA'].copy()
    if not cazyme_pct.empty:
        cazyme_pct['cazyme_percent'] = pd.to_numeric(cazyme_pct['cazyme_percent'], errors='coerce')
        sns.boxplot(data=cazyme_pct, x='species', y='cazyme_percent', ax=ax3)
    ax3.set_ylabel('CAzyme % of Proteome', fontweight='bold')
    ax3.set_xlabel('Species', fontweight='bold')
    ax3.set_title('CAzyme Percentage by Species', fontweight='bold')
    plt.setp(ax3.get_xticklabels(), rotation=ROTATION_ANGLE, ha='right')
    
    # Correlation scatter plots
    if 'virulence_score' in corr_df.columns:
        ax4 = fig.add_subplot(gs[2, 0])
        valid_data = corr_df.dropna(subset=['total_cazymes', 'virulence_score'])
        if not valid_data.empty:
            ax4.scatter(valid_data['total_cazymes'], valid_data['virulence_score'], s=100, alpha=0.6)
            z = np.polyfit(valid_data['total_cazymes'], valid_data['virulence_score'], 1)
            p = np.poly1d(z)
            xs = sorted(valid_data['total_cazymes'])
            ax4.plot(xs, p(xs), "r--", alpha=0.8, linewidth=2)
            ax4.set_xlabel('Total CAzymes', fontweight='bold')
            ax4.set_ylabel('Virulence Score', fontweight='bold')
            ax4.set_title('CAzymes vs Virulence', fontweight='bold')
        
        ax5 = fig.add_subplot(gs[2, 1])
        valid_data2 = corr_df.dropna(subset=['gh_count', 'virulence_score'])
        if not valid_data2.empty:
            ax5.scatter(valid_data2['gh_count'], valid_data2['virulence_score'], s=100, alpha=0.6, color='orange')
            z = np.polyfit(valid_data2['gh_count'], valid_data2['virulence_score'], 1)
            p = np.poly1d(z)
            xs2 = sorted(valid_data2['gh_count'])
            ax5.plot(xs2, p(xs2), "r--", alpha=0.8, linewidth=2)
            ax5.set_xlabel('GH Count', fontweight='bold')
            ax5.set_ylabel('Virulence Score', fontweight='bold')
            ax5.set_title('GH Enzymes vs Virulence', fontweight='bold')
    
    plt.suptitle('CAzyme Profiles & Correlation with Barley Virulence', fontsize=14, fontweight='bold')
    fig.savefig(f"{output_dir}/Fig5_CAzyme_Virulence.png", dpi=300, bbox_inches='tight')
    print(f"✓ Saved: Fig5_CAzyme_Virulence.png")
    plt.close()

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <analysis_root>")
        sys.exit(1)
    
    analysis_root = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else f"{analysis_root}/08_figures"
    
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    print(f"Loading data from: {analysis_root}")
    data = load_data(analysis_root)
    
    print(f"Generating figures in: {output_dir}")
    
    # Generate all figures
    figure_1_heat_stress(data, output_dir)
    figure_2_cold_stress(data, output_dir)
    figure_3_optimum(data, output_dir)
    figure_4_barley_pathogenicity(data, output_dir)
    
    # Genome analyses
    figure_4a_structural_variation(data, output_dir)
    figure_4b_accessory_genes(data, output_dir)
    figure_4c_lineage_fissions(data, output_dir)
    figure_4d_effector_expansions(data, output_dir)
    
    # CAzyme correlations
    figure_5_cazyme_virulence(data, output_dir)
    
    print(f"\n✓ All figures generated in: {output_dir}")

if __name__ == "__main__":
    main()