#!/usr/bin/env bash

exec ionice -c 3 smbd -F --no-process-group </dev/null