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


## Prerequisites

To run things (either locally, or on HPC), a few requirements have to be met: `docker`, `apptainer`, `python`, `git`, and `make` obviously need to be installed.


## Local Workspace (Docker-based)

The fastest path to a working development shell on a local machine is:

```shell
git clone https://github.com/camarocico/ALMA.git
cd ALMA
git submodule update --init
make bootstrap
```

The `make bootstrap` command will initialize the pipeline submodule and pull the code (or you can update it manually, as above). It further validates the expected workspace layout and prints exact next actions if optional assets such as `pipeline-testdata/`, CASA measures data, or the CASA tarball are missing.

If you need regression tests or other data-heavy workflows, clone the test data repository separately:

```shell
git clone https://open-bitbucket.nrao.edu/scm/pipe/pipeline-testdata.git pipeline-testdata
```

The next step is to build the `pipeline-dev` container:

```shell
make build-dev
```

If you need CASA measures data, fetch it explicitly (this will build the Docker `pipeline-dev` image, if that has not yet been done):

```shell
./docker/download.sh --data
```

If you need the full `pipeline-casa` runtime container, fetch the CASA tarball too:

```shell
./docker/download.sh --casa
```

and then build the `pipeline-casa` container:

```shell
make build-casa
```


## HPC Workspace (Apptainer-based)

To run containers on HPC systems (such as [Habrok](https:wiki.hpc.rug.nl/habrok/start)), one needs to use Apptainer, since Docker is not usually available on these systems. Apptainer containers can only be created on systems where the user has root privileges, and then transfered manually to the HPC system.

To create the Apptainer containers, we can continue from where we left off in the previous section, and run the build scripts:

```shell
./apptainer/build.sh --dev
./apptainer/build.sh --casa
```

or

```shell
./apptainer/build.sh --all
```

One can the copy the resulting `pipeline-dev.sif` and `pipeline-casa.sif` files to the HPC system, where they can then be run.


# Usage

Use the containers as follows:

-   **`pipeline-dev`:** writing code, running tests, linting, and general development
-   **`pipeline-casa`:** full CASA runtime and full pipeline execution

If you only need to edit code or run tests, use `pipeline-dev`. If you need to run the pipeline inside the full CASA runtime, use `pipeline-casa`. The `pipeline-casa` container requires both the CASA tarball and CASA measures data to be present.


## Common commands

In addition to the setup commands, i.e.:

```shell
make bootstrap
make build-dev
make shell-dev
make build-casa
make shell-casa
```

the `Makefile` also has some test commands. The unit tests for the pipeline can be run via the following command:

```sh
make test-unit
```

which will use the `pipeline-dev` container (both Docker and Apptainer).

Regression tests can also be run via `make` shortcuts:

```sh
make test-regression-fast
make test-regression
```

****NOTE**** Regression test hang at the moment, both in `docker` and `apptainer`.
