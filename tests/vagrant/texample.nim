discard """
"""

import
  nim_utils/files,
  nim_utils/shell_utils,
  os,
  sugar,
  strformat,
  strutils,
  sequtils

proc countDockerContainers(): int =
  let x = "docker ps".execOutput.strip()
  # minus 1 because header row
  return countLines(x) - 1

let nginxConfigFile = "/etc/nginx/sites-available/example.conf"
let nginxEnabledFile = "/etc/nginx/sites-enabled/example.conf"

let tcmConfigFile = "/opt/tiny-container-manager/example.yaml"

block Before:
  assert countDockerContainers() == 0, fmt"{countDockerContainers()} != 0"
  assert nginxConfigFile.fileType == ftDoesNotExist
  assert nginxEnabledFile.fileType == ftDoesNotExist
  assert tcmConfigFile.fileType == ftDoesNotExist
block WriteFile:
  let fileContents = """
name: example
image: nginx:latest
containerPort: 80
host: example.com
  """
  tcmConfigFile.writeFile(fileContents)
block Waiting:
  assert tcmConfigFile.fileType == ftFile
  let timeoutSeconds = 60
  sleep(timeoutSeconds * 1000)
block Checking:
  assert tcmConfigFile.fileType == ftFile
  assert countDockerContainers() == 1, fmt"{countDockerContainers()} != 1"
  assert nginxConfigFile.fileType == ftFile
  assert nginxEnabledFile.fileType == ftSymlink
