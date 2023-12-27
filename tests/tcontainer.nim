import
  asyncdispatch,
  os,
  strformat,
  strutils,
  std/tempfiles,
  tiny_container_manager/[
    container,
    docker,
    shell_utils
  ],
  test_utils/container_testing,
  unittest

if dockerRunning():
  block CreatingAContainer:
    let testC = testContainer()
    if testC.isHealthy:
      waitFor testC.tryStopContainer()
      waitFor testC.tryRemoveContainer()

    assert not testC.isHealthy()
    # Let's create it
    waitFor testC.createContainer()
    waitFor testC.tryStopContainer()
    waitFor testC.tryRemoveContainer()

block ReadingFromFile:
  let (fd,t) = createTempFile("", "")
  fd.close()
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

block ContainerWithMounts:
  let (fd,t) = createTempFile("", "")
  fd.close()
  let name = "example"
  let image = "alpine:latest"
  let containerPort = 6969
  let host = "example.com"
  let contents = fmt"""
  name: {name}
  image: {image}
  containerPort: {containerPort}
  host: {host}
  mounts:
  - kind: hostdir
    mountPoint: /opt/test/
    hostDir: /opt/liveness/
  """
  writeFile(t, contents)
  let c = parseContainer(t)
  assert c.mounts.len == 1
  let mount = c.mounts[0]
  check mount.kind == mkHostDir
  check mount.mountPoint == "/opt/test/"
  check mount.hostDir == "/opt/liveness/"

block WritingFile:
  let tmpDir = createTempDir("tcontainer-writingfile-","")
  let c = testContainer()
  c.writeFile(dir = tmpDir)
  let fname = tmpDir / c.filename()
  let c2 = parseContainer(fname)
  assert c2.name == c.name
  assert c2.image == c.image
  assert c2.containerPort == c.containerPort
  assert c2.host == c.host
