#!/bin/bash

VENVDIR=$HOME/.venv
PYTHONVER=3.9.7
VENV=gnirs

source $VENVDIR/$PYTHONVER/$VENV/bin/activate

gnirsdm "$@"
