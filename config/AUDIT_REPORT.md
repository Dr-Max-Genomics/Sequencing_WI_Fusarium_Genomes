# MSA_stress conference figures — audit & corrections (2026-07-05)

Compared `suggested_scripts/` (template) vs `used_scripts/` (HPC run), audited every
data output in `conference_figs/`, and regenerated corrected figures.

## Corrected figures → `conference_figs/08_figures_corrected/`
Data files were rebuilt by `corrected_scripts/fix_data.py`; originals kept as `*.preaudit`.

| Fig | Status | Notes |
|-----|--------|-------|
| Fig1 Heat Stress      | ✅ ready | correct data/labels. No error bars (source std/sem empty). |
| Fig2 Cold Stress      | ✅ ready | same caveat as Fig1. |
| Fig3 Optimum Growth   | ✅ ready | has error bars. |
| Fig4 Pathogenicity    | ✅ ready | severity colors + error bars. |
| Fig4a Structural Var. | ✅ FIXED | **N50 recomputed from assemblies** (was garbage for 7/12: e.g. 642–3625 bp). |
| Fig4d Effector Exp.   | ✅ FIXED | expansion panel rebuilt (was "missing columns" — species split on space). |
| Fig5 CAzyme–Virulence | ✅ FIXED | **correlation columns were shifted/mislabelled**; rebuilt + correlations recomputed. |
| Fig4b Accessory Genes | ⚠️ labelled but DATA SUSPECT | see below — needs step 02 rerun. |
| Fig4c Chromosomal Fis.| ⛔ PENDING | synteny produced **zero data**; placeholder written — needs step 03 rerun. |

## Bugs found
1. **Synteny (03) — fatal.** `PAF_OUT` interpolated the reference's full path into the
   output filename → every minimap2 redirect failed (`No such file or directory`),
   0 PAFs, empty `synteny_pairwise.tsv`. Fig4c was blank. → `03_synteny_FIXED.sh`.
2. **Genome N50 (01).** N50 wrong for 7/12 isolates (642–3625 bp for ~40 Mbp genomes).
   Recomputed from FASTAs; now 1.7–9 Mbp.
3. **Correlation (07).** `correlation_data.tsv` header was offset from the values:
   `gh_count` held the CAzyme % (16.23), real `ce_count` dropped, `total_proteins`
   posing as `total_cazymes`. Every correlation label was wrong. Rebuilt from
   `cazyme_summary.tsv` + `pathogenicity_summary.tsv`.
4. **Effector expansion (04).** Summary collapsed to one junk row (species "F. xxx"
   split on the space). Rebuilt per species.
5. **Accessory genome (02) — methodological.** `core_genes = 11469` for ALL isolates
   and a **negative accessory count** (sample 9 = −27). Core set exceeds the smaller
   FSAMSC genomes' total genes → accessory ≈ 0/negative for graminearum. The pangenome
   step needs review/rerun; current Fig4b values for samples 7–12 are unreliable.

## Two analyses need re-running on HPC (corrected scripts provided)
- **03 synteny (Fig4c)** → `corrected_scripts/03_synteny_FIXED.sh` (needs minimap2).
  Fixes the output-path bug, duplicate alignments, and an awk precedence bug.
- **02 accessory (Fig4b)** → `corrected_scripts/02_accessory_genome_FIXED.sh` (needs mmseqs2).
  Replaces the invalid locus_tag/gene-ID presence-absence (Funannotate IDs reset per
  genome, so IDs were not comparable across isolates) with proper MMseqs2 orthogroup
  clustering; per-isolate core/accessory/unique counts are now non-negative and sum to
  each proteome. Tunable via MIN_SEQ_ID (0.5) and COV (0.8).

Both were `bash -n` validated. After re-running either on Ceres, regenerate figures:
`python3 corrected_scripts/08_generate_figures.py conference_figs conference_figs/08_figures_corrected`
