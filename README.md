# OpenCoarrays-ft

[![DOI](https://zenodo.org/badge/295230177.svg)](https://zenodo.org/badge/latestdoi/295230177)

Artifacts for research paper:

N. Weeks, G. Luecke, G. Prabhu, "Refining Fortran Failed Images", 2020 [submitted]

## Usage

The recommended method for local testing is using Docker, version 19.03 or newer.

NERSC users may also use [Shifter](https://github.com/NERSC/shifter).

The included Makefile automates commands for pulling, running and optionally building the container image.

### Docker

To pull Docker image and execute the three example applications (described in the paper) in the test/ direcory:

```
make pull
make monte_carlo_pi-1
make monte_carlo_pi-2
make C.6.8
```

By default, 8 (Fortran) images (processes) will be used.

To use a different number, override the NPROC macro; e.g., `make NPROC=16 C.6.8`

### Shifter

To run the container at NERSC using Shifter:

```
make shifter-pull
make salloc
make shifter-monte_carlo_pi-1
make shifter-monte_carlo_pi-2
make shifter-C.6.8
```
