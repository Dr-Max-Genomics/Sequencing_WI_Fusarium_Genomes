#!/usr/bin/env bash
# =======================================================================
# igv_prep.sh
# Purpose : Build ONE self-consistent "source of truth" bundle per isolate:
#             1. name map   : Flye name -> polished name -> funannotate scaffold_N
#                             (+ which sequences were dropped by the 1 kb filter)
#             2. genome.fa  : the funannotate annotate_results *.scaffolds.fa
#             3. gff3       : the matching annotation (all scaffolds, IGV-safe)
#             4. final.bam  : reads RE-ALIGNED to genome.fa (same names + coords)
#             5. coverage   : 10 kb windowed bedgraph (+ mosdepth summary if found)
#             6. igv_session.xml (relative paths; open directly in IGV)
#
# Usage   : bash scripts/igv_prep.sh <sample_id> [--map-only]
#           --map-only : only write the name map + sanity checks (no remap).
# Run     : interactively or via srun on Ceres (not an array job).
#
# Overridable env vars:
#   READS=/path/reads.fastq   (default: ${TRIMMED_DIR}/${sample_id}.fastq)
#   IGV_DIR=/path/out         (default: <batch root>/igv_bundles)
#   THREADS=16  WINDOW=10000
# =======================================================================
set -euo pipefail

SAMPLE_ID="${1:-}"
MODE="${2:-full}"
[[ -n "${SAMPLE_ID}" ]] || { echo "Usage: bash scripts/igv_prep.sh <sample_id> [--map-only]" >&2; exit 1; }

PROJECT_ROOT="${PROJECT_ROOT:-/project/silage_microbiome/max.chi/fusarium_sequencing}"
source "${PROJECT_ROOT}/config/paths.sh"

THREADS="${THREADS:-16}"
WINDOW="${WINDOW:-10000}"
OUT="${IGV_DIR:-$(dirname "${ASSEMBLY_DIR}")/igv_bundles}/${SAMPLE_ID}"
mkdir -p "${OUT}"

FUN_NAME=$(awk -F'\t' -v sid="${SAMPLE_ID}" '$2==sid {print $6; exit}' "${MANIFEST}")
[[ -n "${FUN_NAME}" ]] || { echo "ERROR: ${SAMPLE_ID} not in ${MANIFEST}" >&2; exit 1; }

ANNOT_DIR="${FUN_PREDICT_DIR}/${FUN_NAME}/annotate_results"
FLYE_FA="${ASSEMBLY_DIR}/${SAMPLE_ID}_flye/assembly.fasta"
POLISHED_FA="${POLISHED_DIR}/${SAMPLE_ID}_polished.fasta"
SORTED_FA="${POLISHED_DIR}/${SAMPLE_ID}_sort.fa"

shopt -s nullglob
sc=( "${ANNOT_DIR}"/*.scaffolds.fa ); cf=( "${ANNOT_DIR}"/*.contigs.fsa ); gf=( "${ANNOT_DIR}"/*.gff3 )
[[ ${#sc[@]} -eq 1 ]] || { echo "ERROR: expected exactly 1 *.scaffolds.fa in ${ANNOT_DIR}, found ${#sc[@]}" >&2; exit 1; }
[[ ${#gf[@]} -eq 1 ]] || { echo "ERROR: expected exactly 1 *.gff3 in ${ANNOT_DIR}, found ${#gf[@]}" >&2; exit 1; }
FINAL_FA="${sc[0]}"; GFF3="${gf[0]}"; CONTIGS_FSA="${cf[0]:-}"

echo "Flye assembly : ${FLYE_FA}"
echo "Polished      : ${POLISHED_FA}"
echo "Sorted (>=1kb): ${SORTED_FA}"
echo "FINAL (truth) : ${FINAL_FA}"
echo "GFF3          : ${GFF3}"
echo "contigs.fsa   : ${CONTIGS_FSA:-<none>}"
echo "Output        : ${OUT}"

# -----------------------------------------------------------------------
# 1) Name map. Sequences are matched by MD5 of the UPPER-CASED sequence
#    (soft-masking changes case only), Flye -> polished by name (polishing
#    changes sequence/length but dorado polish keeps the header).
# -----------------------------------------------------------------------
python3 - "${FLYE_FA}" "${POLISHED_FA}" "${FINAL_FA}" "${CONTIGS_FSA}" "${GFF3}" "${OUT}/${SAMPLE_ID}.name_map.tsv" <<'PYEOF'
import sys, hashlib, os
flye, pol, final, contigs, gff3, out = sys.argv[1:7]

def read(path):
    d, name, buf = {}, None, []
    if not path or not os.path.isfile(path): return d
    with open(path) as f:
        for line in f:
            line = line.rstrip()
            if line.startswith('>'):
                if name is not None: d[name] = ''.join(buf).upper()
                name, buf = line[1:].split()[0], []
            else: buf.append(line)
    if name is not None: d[name] = ''.join(buf).upper()
    return d

F, P, S, C = read(flye), read(pol), read(final), read(contigs)
md5 = lambda s: hashlib.md5(s.encode()).hexdigest()
S_by_md5 = {md5(s): n for n, s in S.items()}
C_by_md5 = {md5(s): n for n, s in C.items()}

genes = {}
if os.path.isfile(gff3):
    for line in open(gff3):
        if line.startswith('#'): continue
        p = line.split('\t')
        if len(p) > 8 and p[2] == 'gene': genes[p[0]] = genes.get(p[0], 0) + 1

rows = []
for pn, ps in sorted(P.items(), key=lambda kv: -len(kv[1])):
    h = md5(ps)
    sn = S_by_md5.get(h, '')
    rows.append((pn, len(ps), len(F[pn]) if pn in F else '', sn, len(S[sn]) if sn else '',
                 C_by_md5.get(h, '') if C else 'NA', genes.get(sn, 0) if sn else '',
                 'retained' if sn else ('dropped_<1kb' if len(ps) < 1000 else 'MISSING_IN_FINAL')))
with open(out, 'w') as o:
    o.write('polished_name\tpolished_len\tflye_len_same_name\tfinal_scaffold\tfinal_len\tcontigs_fsa_name\tgenes\tstatus\n')
    for r in rows: o.write('\t'.join(map(str, r)) + '\n')

print(f"\nSequences: Flye={len(F)} polished={len(P)} final={len(S)}")
print(f"  total bp: polished={sum(map(len,P.values())):,}  final={sum(map(len,S.values())):,}")
print(f"  polished names found in Flye by name : {sum(n in F for n in P)}/{len(P)}")
bad = [r for r in rows if r[-1] == 'MISSING_IN_FINAL']
print(f"  dropped (<1 kb)                       : {sum(r[-1].startswith('dropped') for r in rows)}")
print(f"  MISSING_IN_FINAL (>=1kb, not matched) : {len(bad)}  <-- should be 0")
unk = sorted(set(genes) - set(S))
print(f"  GFF3 seqids not in final FASTA        : {len(unk)}  <-- should be 0 {unk[:5]}")
print(f"  name map -> {out}")
PYEOF

[[ "${MODE}" == "--map-only" ]] && { echo "map-only: done."; exit 0; }

# -----------------------------------------------------------------------
# 2) Bundle: genome + annotation, same names as everything downstream
# -----------------------------------------------------------------------
GENOME="${OUT}/${SAMPLE_ID}.genome.fa"
cp -f "${FINAL_FA}" "${GENOME}"
cp -f "${GFF3}" "${OUT}/${SAMPLE_ID}.annotation.gff3"

module load samtools minimap2 2>/dev/null || true
samtools faidx "${GENOME}"

# -----------------------------------------------------------------------
# 3) Re-align reads to the FINAL FASTA (aligned.bam from A05 is against the
#    UNPOLISHED Flye assembly: wrong names *and* slightly shifted coords).
# -----------------------------------------------------------------------
READS="${READS:-${TRIMMED_DIR}/${SAMPLE_ID}.fastq}"
BAM="${OUT}/${SAMPLE_ID}.final.bam"
[[ -s "${READS}" ]] || { echo "ERROR: reads not found: ${READS} (set READS=...)" >&2; exit 1; }
if [[ ! -s "${BAM}" ]]; then
    minimap2 -ax map-ont -t "${THREADS}" "${GENOME}" "${READS}" \
        | samtools sort -@ "${THREADS}" -o "${BAM}"
    samtools index -@ "${THREADS}" "${BAM}"
fi
samtools flagstat -@ "${THREADS}" "${BAM}" > "${OUT}/${SAMPLE_ID}.flagstat.txt"

# -----------------------------------------------------------------------
# 4) Coverage (primary alignments only; windowed mean depth bedgraph)
# -----------------------------------------------------------------------
if command -v mosdepth >/dev/null 2>&1; then
    mosdepth -t "${THREADS}" -n --by "${WINDOW}" -F 2308 "${OUT}/${SAMPLE_ID}.cov" "${BAM}"
    zcat "${OUT}/${SAMPLE_ID}.cov.regions.bed.gz" > "${OUT}/${SAMPLE_ID}.cov_${WINDOW}bp.bedgraph"
else
    samtools depth -a -G 2308 "${BAM}" | awk -v w="${WINDOW}" 'BEGIN{OFS="\t"}
        { b=int(($2-1)/w); if($1!=c||b!=k){ if(c!="") print c,k*w,k*w+n,s/n; c=$1;k=b;s=0;n=0 } s+=$3;n++ }
        END{ if(c!="") print c,k*w,k*w+n,s/n }' > "${OUT}/${SAMPLE_ID}.cov_${WINDOW}bp.bedgraph"
fi

# -----------------------------------------------------------------------
# 5) IGV session (relative paths; keep the folder together)
# -----------------------------------------------------------------------
FIRST=$(awk 'NR==1{print $1}' "${GENOME}.fai")
cat > "${OUT}/${SAMPLE_ID}.igv_session.xml" <<XML
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<Session genome="${SAMPLE_ID}.genome.fa" hasGeneTrack="false" hasSequenceTrack="true" locus="${FIRST}" version="8">
    <Resources>
        <Resource path="${SAMPLE_ID}.annotation.gff3"/>
        <Resource path="${SAMPLE_ID}.final.bam"/>
    </Resources>
</Session>
XML

echo "Done. Copy this whole folder to your PC and open ${SAMPLE_ID}.igv_session.xml in IGV:"
echo "  ${OUT}"
