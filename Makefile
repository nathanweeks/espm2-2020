.POSIX:

## Alternatively, build image (warning: may take ~2 hours)
# 1. Build and tag container image (optional: tag intermediate images for development/debugging)
# (optional) make gcc
# (optional) make ulfm2
# make opencoarrays # or opencoarrays-debug

REPO=ghcr.io/nathanweeks/espm2-2020
GCC_TAG=gcc-9.3.0-pr87939_alpine3.12.0
ULFM2_TAG=ulfm2-20200131-0823ee3_$(GCC_TAG)
OPENCOARRAYS_TAG=opencoarrays-2.8.0-2d11794_$(ULFM2_TAG)

# number of processors to use for testing
NPROC=8

SHIFTER_REPO=registry.services.nersc.gov/nweeks/espm2-2020
SHIFTER_IMAGE=$(SHIFTER_REPO):$(OPENCOARRAYS_TAG)

DOCKER_BUILD=DOCKER_BUILDKIT=1 BUILDKIT_INLINE_CACHE=1 docker build

########################################
# Build
########################################

opencoarrays: FORCE
	$(DOCKER_BUILD) --target=opencoarrays-ft -t $(REPO):$(OPENCOARRAYS_TAG) .
	docker tag $(REPO):$(OPENCOARRAYS_TAG) $(REPO):latest

########################################
# Test
########################################
test: FORCE
	$(DOCKER_BUILD) --target=opencoarrays-ft-test -t $(REPO):test-$(OPENCOARRAYS_TAG) . && \
	docker rmi $(REPO):test-$(OPENCOARRAYS_TAG)

########################################
# Pull existing image
########################################

pull:
	docker pull $(REPO):$(OPENCOARRAYS_TAG)

# build OpenCoarrays with verbose debugging output

opencoarrays-debug: FORCE
	$(DOCKER_BUILD) --build-arg OMPI_MCA_mpi_ft_verbose=1 --build-arg BUILD_TYPE=Debug --target=opencoarrays-ft -t $(REPO):debug-$(OPENCOARRAYS_TAG) .

# optional targets (explicitly tags the stages in multi-stage build for further development of those stages)

ulfm2: FORCE
	$(DOCKER_BUILD) --target=ulfm2 --tag=$(REPO):$(ULFM2_TAG) .

ulfm2-builder: FORCE
	$(DOCKER_BUILD) --target=ulfm2-builder --tag=$(REPO):$(ULFM2_TAG) .

gcc: FORCE
	$(DOCKER_BUILD) --target=gcc-pr87939 --tag=$(REPO):$(GCC_TAG) .

# Generate a Singularity image from a Docker image
# (assumes "make opencoarrays")
# https://gitnub.com/singularityhub/docker2singularity

singularity: FORCE
	docker run -v /var/run/docker.sock:/var/run/docker.sock \
    -v /tmp/singularity:/output \
    --privileged -t --rm \
    quay.io/singularity/docker2singularity:3.6.3 \
    $(REPO):$(OPENCOARRAYS_TAG)


########################################
# Test (Docker)
########################################

monte_carlo_pi-1:
	docker run -it --rm --log-driver=none -v ${PWD}/test:/mnt -w /mnt $(REPO):$(OPENCOARRAYS_TAG) caf -o $@.x $@.f90
	docker run -it --rm --log-driver=none -v ${PWD}/test:/mnt:ro -w /mnt $(REPO):$(OPENCOARRAYS_TAG) cafrun -np $(NPROC) $@.x

monte_carlo_pi-2:
	docker run -it --rm --log-driver=none -v ${PWD}/test:/mnt -w /mnt $(REPO):$(OPENCOARRAYS_TAG) caf -o $@.x $@.f90
	docker run -it --rm --log-driver=none -v ${PWD}/test:/mnt:ro -w /mnt $(REPO):$(OPENCOARRAYS_TAG) cafrun -np $(NPROC) $@.x

C.6.8:
	docker run -it --rm --log-driver=none -v ${PWD}/test:/mnt -w /mnt $(REPO):$(OPENCOARRAYS_TAG) caf -o $@.x $@.f90
	docker run -it --rm --log-driver=none -v ${PWD}/test:/mnt:ro -w /mnt $(REPO):$(OPENCOARRAYS_TAG) cafrun -np $(NPROC) $@.x

########################################
# Test (Shifter @ NERSC)
# make shifterimg-pull
# make ...other target...
########################################

shifterimg-pull: FORCE
	shifterimg pull $(SHIFTER_IMAGE)

salloc: FORCE
	salloc -C knl -t 1:00:00 -q interactive --nodes=1 --image=$(SHIFTER_IMAGE)

shifter-C.6.8: test/C.6.8.x
	shifter cafrun -np $(NPROC) $?

test/C.6.8.x: test/C.6.8.f90
	shifter caf -o $@ $?

shifter-monte_carlo_pi-1: test/monte_carlo_pi-1.x
	shifter cafrun -np $(NPROC) $?

test/monte_carlo_pi-1.x: test/monte_carlo_pi-1.f90
	shifter caf -o $@ $?

shifter-monte_carlo_pi-2: test/monte_carlo_pi-2.x
	shifter cafrun -np $(NPROC) $?

test/monte_carlo_pi-2.x: test/monte_carlo_pi-2.f90
	shifter caf -o $@ $?

test/benchmark.x: test/benchmark.f90
	shifter --image=${SHIFTER_IMAGE} caf -o $@ $?

benchmark: test/benchmark.x
	sbatch --image=${SHIFTER_IMAGE} test/benchmark.job

test/sole_survivor.x: test/sole_survivor.f90
	shifter --image=${SHIFTER_IMAGE} caf -o $@ $?

sole_survivor: test/sole_survivor.x
	sbatch --image=${SHIFTER_IMAGE} test/sole_survivor.job

clean:
	rm -rf ./test/benchmark.out ./test/benchmark_no-ft.out ./test/*.x

########################################
# Build / push to NERSC's private registry
# https://docs.nersc.gov/development/shifter/how-to-use/#using-nerscs-private-registry
########################################

# NERSC Shifter
# make shifter-build
# make shifter-login
# make shifter-push

shifter-build: FORCE
	$(DOCKER_BUILD) --target=opencoarrays-ft --tag=$(SHIFTER_REPO):$(OPENCOARRAYS_TAG) .
	docker tag $(SHIFTER_REPO):$(OPENCOARRAYS_TAG) $(SHIFTER_REPO):latest
	
shifter-login: FORCE
	docker login registry.services.nersc.gov

shifter-push: FORCE
	docker push $(SHIFTER_REPO):$(OPENCOARRAYS_TAG)
	docker push $(SHIFTER_REPO):latest

shifter-push-debug: FORCE
	docker push $(SHIFTER_REPO):debug-$(OPENCOARRAYS_TAG)

FORCE:
