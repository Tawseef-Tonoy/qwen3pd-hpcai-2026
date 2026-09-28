# BASIC-REF07-001 Raw Run Envelope

Experiment:

    BASIC-REF07-001

Purpose:

    Raw runtime evidence for faithful reproduction of frozen Firmus
    reference script 07.

Submission rule:

    Submit from this directory.

Because the unmodified reference script uses:

    ROOT=${SLURM_SUBMIT_DIR}

its runtime artifacts will appear under:

    runs/<SLURM_JOB_ID>/

and Slurm stdout/stderr under:

    runs/<SLURM_JOB_ID>.out
    runs/<SLURM_JOB_ID>.err

Worker container-home directories are created under:

    home/

Do not edit completed raw artifacts in place.
