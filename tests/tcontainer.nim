import
  asyncdispatch,
  os,
  strformat,
  strutils,
  std/tempfiles

import
  tiny_container_manager/[
    container,
    docker,
    shell_utils
  ]

import
  test_utils/container_testing

if dockerRunning():
  block CreatingAContainer:
    let testC = testContainer()
    if testC.isHealthy:
      waitFor testC.tryStopContainer()
      waitFor testC.tryRemoveContainer()

    assert not testC.isHealthy()
    # Let's create it
    waitFor testC.createContainer()

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

block WritingFile:
  let tmpDir = createTempDir("tcontainer-writingfile-","")
  let c = testContainer()
  c.writeFile(dir = tmpDir)
  let fname = tmpDir / c.filename()
  let c2 = parseContainer(fname)
  assert c2 == c