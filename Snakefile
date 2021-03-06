import pandas as pd
import os
from snakemake.utils import validate

singularity: "docker://continuumio/miniconda3:4.6.14"

report: "report/workflow.rst"

###### Config file and sample sheets #####
configfile: "config.yaml"
validate(config, schema="schemas/config.schema.yaml")

OUTDIR = config["outdir"]
LOGDIR = config["logdir"]

samples = pd.read_csv(config["samples"],sep="\t").set_index("sample", drop=False)
validate(samples, schema="schemas/samples.schema.yaml")

units = pd.read_csv(config["units"],sep="\t", dtype=str).set_index(["sample", "unit"], drop=False)
units.index = units.index.set_levels([i.astype(str) for i in units.index.levels])  # enforce str in index
validate(units, schema="schemas/units.schema.yaml")

# contigs in reference genome
if os.stat(config["contigs"]).st_size != 0:
    print(os.stat(config["contigs"]).st_size)
    contigs = pd.read_csv(config["contigs"],sep="\t",header=None,usecols=[0],squeeze=True,dtype=str)
else:
    contigs = pd.read_csv(config["ref"]["genome"] + ".fai", sep="\t",
                            header=None, usecols=[0], squeeze=True, dtype=str)

include: "rules/common.smk"

##### Target rules #####

rule all:
    input:
        f"{OUTDIR}/annotated/all.vcf.gz",
        f"{OUTDIR}/annotated/all.vep.vcf.gz",
        ["{OUTDIR}/annotated/{sample}_mutect.vep.vcf.gz".format(OUTDIR=OUTDIR,sample=getattr(row, 'sample')) for row in samples.itertuples() if (getattr(row, 'control') != "-")],
        f"{OUTDIR}/qc/multiqc.html",
        f"{OUTDIR}/plots/depths.svg",
        f"{OUTDIR}/plots/allele-freqs.svg"


##### Modules #####

include: "rules/mapping.smk"
include: "rules/calling.smk"
include: "rules/filtering.smk"
include: "rules/stats.smk"
include: "rules/qc.smk"
include: "rules/annotation.smk"
