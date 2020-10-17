# OpenCoarrays-ft

[![DOI](https://zenodo.org/badge/295230177.svg)](https://zenodo.org/badge/latestdoi/295230177)

Artifacts for research paper:

N. Weeks, G. Luecke, G. Prabhu, "Refining Fortran Failed Images", 2020 IEEE/ACM 5th International Workshop on Extreme Scale Programming Models and Middleware (ESPM2) [accepted]

## Usage

The recommended method for local testing is using Docker, version 19.03 or newer.

NERSC users may also use [Shifter](https://github.com/NERSC/shifter).

The included Makefile automates commands for pulling, running and optionally building the container image.

### Docker

To pull the existing production container image and execute the three example applications (described in the paper) in the test/ direcory using Docker (assuming local Docker daemon):

```
make pull
make monte_carlo_pi-1
make monte_carlo_pi-2
make C.6.8
```

By default, 8 (Fortran) images (processes) will be used.

To use a different number, override the NPROC macro; e.g., `make NPROC=16 C.6.8`

To build a container image from source:

```
make
```

See the Dockerfile for other build targets.

### Shifter

To run the container at NERSC using Shifter:

```
make shifter-pull
make salloc
make shifter-monte_carlo_pi-1
make shifter-monte_carlo_pi-2
make shifter-C.6.8
```

To run the (batch) benchmarks featured in the paper:
```
make shifter-pull
make benchmark
make sole_survivor
```
