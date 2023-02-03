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

pushd tests/vagrant

vagrant destroy -f

vagrant up

time=30
echo "Waiting for $time seconds"
sleep $time

echo "sshing into vm to run tests"
vagrant ssh -c "sudo bash -c /tcm/tests/vagrant/run_tests_in_vm.sh"

if [ $printLogs ]; then
    vagrant ssh -c "sudo journalctl -u tiny-container-manager.service | cat"
fi

