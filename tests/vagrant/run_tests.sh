#!/usr/bin/env bash

printLogs=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --log)
      printLogs=true
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      shift # past argument
      ;;
  esac
done

if [[ -f "valgrind-output" ]]; then
  rm valgrind-output
fi

pushd tests/vagrant

vagrant destroy -f

set -e

vagrant up

echo "sshing into vm to run tests"
vagrant ssh -c "sudo bash -c /tcm/tests/vagrant/run_tests_in_vm.sh"
RET_VAL=$?

if [ $printLogs ]; then
    vagrant ssh -c "sudo journalctl -u tiny-container-manager.service | cat"
fi

exit $REV_VAL
