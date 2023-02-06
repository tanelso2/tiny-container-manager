discard """
"""

import
  nim_utils/files,
  nim_utils/shell_utils,
  os,
  sugar,
  strformat,
  strutils,
  sequtils,
  unittest

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
block Waiting:
  check tcmConfigFile.fileType == ftFile
  let timeoutSeconds = 30
  sleep(timeoutSeconds * 1000)
block Checking:
  check tcmConfigFile.fileType == ftFile
  check countDockerContainers() == 1
  check nginxConfigFile.fileType == ftFile
  check nginxEnabledFile.fileType == ftSymlink
