discard """
"""

import
  nim_utils/files,
  nim_utils/shell_utils,
  nim_utils/logline,
  os,
  sugar,
  strformat,
  strutils,
  sequtils,
  times,
  unittest,
  ../test_utils/waiting

proc countDockerContainers(): int =
  let x = "docker ps".execOutput.strip()
  # minus 1 because header row
  return countLines(x) - 1

let nginxConfigFile = "/etc/nginx/sites-available/example.conf"
let nginxEnabledFile = "/etc/nginx/sites-enabled/example.conf"

let tcmConfigFile = "/opt/tiny-container-manager/containers/example.yaml"

block Before:
  check tcmConfigFile.fileType == ftDoesNotExist
  check countDockerContainers() == 0
  check nginxConfigFile.fileType == ftDoesNotExist
  check nginxEnabledFile.fileType == ftDoesNotExist
block WriteFile:
  let fileContents = """
name: example
image: nginx:latest
containerPort: 80
host: example.com
  """
  tcmConfigFile.writeFile(fileContents)
block Checking:
  waitForChecks 300:
    assert tcmConfigFile.fileType == ftFile
    assert countDockerContainers() == 1
    assert nginxConfigFile.fileType == ftFile
    assert nginxEnabledFile.fileType == ftSymlink
