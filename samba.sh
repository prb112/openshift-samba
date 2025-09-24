#!/usr/bin/env bash

exec ionice -c 3 smbd --no-process-group </dev/null