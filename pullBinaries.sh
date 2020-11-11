#!/bin/bash

export DOTFILE_REPO="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"


curl -L -o ${DOTFILE_REPO}/binary/google-java-format.jar https://github.com/google/google-java-format/releases/download/google-java-format-1.9/google-java-format-1.9-all-deps.jar