#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote with one commit on main; a and b are two
# clones of it, standing in for two sessions working the same queue.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git a 2>/dev/null
git -C a -c user.name=e -c user.email=e@e commit -q --allow-empty -m base
git -C a push -q origin HEAD:main 2>/dev/null
git clone -q origin.git b 2>/dev/null
