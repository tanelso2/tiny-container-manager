#!/usr/bin/env bash

results_folder="$PWD/results"
if [[ -d "$results_folder" ]]; then
  rm -r "$results_folder"
fi

for i in {1..10}; do
  echo "Starting test ${i}"
  nimble vTest
  pushd tests/vagrant

  logs_file="${results_folder}/test-${i}-output.txt"
  # Copy logs to file
  vagrant ssh -c "sudo journalctl -u tiny-container-manager.service | cat" > "$logs_file"

  valgrind_file="${results_folder}/test-${i}-valgrind.txt"
  # Copy valgrind output to file
  vagrant ssh -c "cat /tcm/valgrind-output" > "$valgrind_file"

done