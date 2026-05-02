# tests/Makefile — convenience wrappers around tests/run.sh and tests/coverage.sh.
#
# Usage:
#   make -C tests test         # run all tests
#   make -C tests unit         # run unit tests only
#   make -C tests integration  # run integration tests only
#   make -C tests coverage     # run kcov coverage (skips if kcov absent)
#   make -C tests clean        # remove generated artifacts

SHELL := /usr/bin/env bash
TESTS_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
RUN := bash $(TESTS_DIR)run.sh
COVERAGE := bash $(TESTS_DIR)coverage.sh

.PHONY: test unit integration coverage clean

test:
	$(RUN)

unit:
	$(RUN) --unit

integration:
	$(RUN) --integration

coverage:
	$(COVERAGE)

clean:
	rm -rf $(TESTS_DIR)results
	rm -rf $(TESTS_DIR)coverage-out
	rm -rf $(TESTS_DIR).bats
	rm -rf $(TESTS_DIR).bats-libs
