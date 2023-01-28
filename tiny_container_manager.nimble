# Package

version       = "0.2.1"
author        = "Thomas Nelson"
description   = "Tiny container manager"
license       = "MIT"
srcDir        = "src"
bin           = @["tiny_container_manager"]

const nimVersion = "1.6.8"
import strformat

# Dependencies

requires fmt"nim >= {nimVersion}"

requires "jester"
requires "argparse"
requires "prometheus"
requires "https://github.com/tanelso2/nim_utils >= 0.2.0"
requires "https://github.com/tanelso2/yanyl >= 0.0.1"

task test, "Runs the test suite":
  exec "nimble build -y && testament p 'tests/*.nim'"

task choosenim, "Uses choosenim to select correct version of nim":
  exec fmt"choosenim {nimVersion}"

task vTest, "Runs the vagrant tests":
  exec "./tests/vagrant/run_tests.sh --log"
