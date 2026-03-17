# ALMA

This repository is a workspace for developing and running the ALMA pipeline locally. It is *not* the pipeline implementation itself. Instead, it provides the surrounding environment, Docker configuration, local data layout, and documentation needed to work productively with the upstream pipeline code.


# Repository Structure

The repository is split between:

-   repository root: local environment setup, Docker configuration, documentation
-   `pipeline/`: upstream pipeline code, tracked as a git submodule
-   `pipeline-testdata/`: external test and reference data, used mainly for regression and other data-heavy tests

Key paths in this workspace:

| Path                 | Purpose                                                           |
|-------------------- |----------------------------------------------------------------- |
| `apptainer/`         | Scripts for running apptainer containers and sif images on Habrok |
| `pipeline/`          | Upstream pipeline source code (git submodule)                     |
| `docker/`            | Development and CASA runtime container definitions                |
| `pipeline-testdata/` | External test data checkout used by tests                         |
| `raw/`               | Local sample measurement-set data                                 |
| `docs/`              | Workflow, infrastructure, documentation (coming soon)             |


# Quick Start


## Local Workspace (Docker-based)

The fastest path to a working development shell on a local machine is:

```sh
git clone https://github.com/camarocico/ALMA.git
cd ALMA
git submodule update --init
make bootstrap
```

The `make bootstrap` command will initialize the pipeline submodule and pull the code (or you can update it manually, as above). It further validates the expected workspace layout and prints exact next actions if optional assets such as `pipeline-testdata/`, CASA measures data, or the CASA tarball are missing.

If you need regression tests or other data-heavy workflows, clone the test data repository separately:

```sh
git clone https://open-bitbucket.nrao.edu/scm/pipe/pipeline-testdata.git pipeline-testdata
```

If you need CASA measures data, fetch it explicitly (this will build the Docker `pipeline-dev` image):

```sh
./docker/download.sh --data
```

If you need the full `casa` runtime container, fetch the CASA tarball too:

```sh
./docker/download.sh --casa
```
