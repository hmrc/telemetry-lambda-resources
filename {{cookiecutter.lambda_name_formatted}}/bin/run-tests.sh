#!/bin/bash

set -eu

export LOG_LEVEL="DEBUG"
export PYTHONPATH='src'
coverage run --module {{ cookiecutter.unit_test_module }} tests/unit/*_test.py
coverage report --show-missing --skip-empty
flake8 src
