#!/bin/bash
set -e
echo ${INPUT_CMD} > run.sh;
chmod +x ./run.sh;
./run.sh;
