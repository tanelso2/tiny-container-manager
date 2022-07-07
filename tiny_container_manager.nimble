# Package

version       = "0.1.0"
author        = "Thomas Nelson"
description   = "Tiny container manager"
license       = "MIT"
srcDir        = "src"
bin           = @["tiny_container_manager"]


# Dependencies

requires "nim >= 1.6.6"

requires "jester"
requires "prometheus"
requires "yaml >= 0.15.0"

task test, "Runs the test suite":
  exec "testament p 'tests/*.nim'"

task choosenim, "Uses choosenim to select correct version of nim":
  exec "choosenim 1.6.6"
