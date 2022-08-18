import
  asyncdispatch,
  os,
  strformat,
  strutils,
  yaml/serialization,
  streams

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
  assert len(c.mounts) == 0

block MountsDumpTest:
  let mount = Mount(kind: MountKind.s3fs,
                    spec: S3MountSpec(
                      name: "my-mount",
                      mountPath: "/mnt/s3",
                      bucket: "my-bucket",
                      accessKeyId: "aKey",
                      accessKeySecret: "hunter2")
  )
  let c = ContainerSpec(
    name: "example",
    image: "alpine:latest",
    containerPort: 6868,
    host: "example.com",
    mounts: @[mount]
  )
  var s = newFileStream("container-out.yaml", fmWrite)
  dump(c, s)
  s.close()
  s = newFileStream("mount-out.yaml", fmWrite)
  dump(mount, s)
  s.close()


block MountsTest:
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
  mounts:
  - name: s3-mount
    mountPath: /mnt/s3/fs
    kind: s3fs
    bucket: my-bucket
    accessKeyId: aKey
    accessKeySecret: hunter2
  """
  let mContents = fmt"""
  spec:
    name: s3-mount
    mountPath: /mnt/s3/fs
    kind: s3fs
    bucket: my-bucket
    accessKeyId: aKey
    accessKeySecret: hunter2
  """
  var m: Mount
  writeFile(t, mContents)
  var s = newFileStream(t)
  load(s, m)
  s.close()
  assert m.spec.name == "s3-mount2"
  assert m.kind == MountKind.s3fs
  # writeFile(t, contents)
  # let c = parseContainer(t)
  # assert c.name == name
  # assert c.image == image
  # assert c.containerPort == containerPort
  # assert c.host == host
  # assert len(c.mounts) == 1
  # let testMount = c.mounts[0]
  # assert testMount.name == "s3-mount"
  # assert testMount.mountPath == "/mnt/s3/fs"
  # assert testMount.kind == MountKind.s3fs
  # assert testMount.bucket == "my-bucket"
  # assert testMount.accessKeyId == "aKey"
  # assert testMount.accessKeySecret == "hunter2"

