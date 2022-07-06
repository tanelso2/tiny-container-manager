import unittest, os, asyncdispatch,
       strutils,
       strformat
import tiny_container_manager/container,
       tiny_container_manager/docker,
       tiny_container_manager/shell_utils

proc setupTmpDir(): string =
  let f = "mktemp -d".simpleExec().strip()
  fmt"{f}/sites-available".createDir()
  fmt"{f}/sites-enabled".createDir()
  return f

proc testContainer(): Container =
  let t = setupTmpDir()
  let spec = ContainerSpec(name: "test", 
                           image: "nginx:latest", 
                           containerPort: 80, 
                           host: "example.com")
  let testC = newContainer(spec = spec, nginxBase = t)
  return testC

if dockerSocketFileExists():
  suite "Container Suite (requires Docker running)":
    test "Creating a container":
      let testC = testContainer()
      if testC.isHealthy:
        waitFor testC.tryStopContainer()
        waitFor testC.tryRemoveContainer()

      check(not testC.isHealthy())
      # Let's create it
      waitFor testC.createContainer()
      waitFor testC.createNginxConfig()
      check(testC.isNginxConfigCorrect())

suite "Container Suite":
  test "Reading from file":
    let t = "mktemp".simpleExec()
    let name = "example"
    let image = "alpine:latest"
    let containerPort = 6969
    let host = "example.com"
    let contents = fmt"""
    name: {name}
    image: {image}
    containerPort: {containerPort}
    host: {host}
    """
    writeFile(t, contents)
    let c = parseContainer(t)
    check(c.name == name)
    check(c.image == image)
    check(c.containerPort == containerPort)
    check(c.host == host)

