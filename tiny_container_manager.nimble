# Package

version       = "0.2.1"
author        = "Thomas Nelson"
description   = "Tiny container manager"
license       = "MIT"
srcDir        = "src"
bin           = @["tiny_container_manager"]

const nimVersion = "2.0.2"
import strformat

# Dependencies

requires fmt"nim >= {nimVersion}"

requires "jester == 0.6.0"
requires "argparse"
requires "prometheus"
requires "https://github.com/tanelso2/nim_utils == 0.4.0"
requires "yanyl == 1.2.0"

task test, "Runs the test suite":
  exec "nimble build -y && testament p 'tests/*.nim'"

task choosenim, "Uses choosenim to select correct version of nim":
  exec fmt"choosenim {nimVersion}"

task vTest, "Runs the vagrant tests":
  exec "./tests/vagrant/run_tests.sh --log"
