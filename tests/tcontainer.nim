import
  asyncdispatch,
  os,
  strformat,
  strutils

import
  tiny_container_manager/[
    container,
    docker,
    shell_utils
  ]

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
  block CreatingAContainer:
    let testC = testContainer()
    if testC.isHealthy:
      waitFor testC.tryStopContainer()
      waitFor testC.tryRemoveContainer()

    assert not testC.isHealthy()
    # Let's create it
    waitFor testC.createContainer()
    waitFor testC.createNginxConfig()
    assert testC.isNginxConfigCorrect()

block ReadingFromFile:
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
  assert c.name == name
  assert c.image == image
  assert c.containerPort == containerPort
  assert c.host == host

