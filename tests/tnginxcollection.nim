import
  tiny_container_manager/collection,
  tiny_container_manager/collection_test_utils,
  tiny_container_manager/container,
  tiny_container_manager/nginx,
  tiny_container_manager/shell_utils,
  asyncdispatch,
  std/os,
  std/sequtils,
  std/strformat,
  std/sugar,
  std/tempfiles


let mockConfig = NginxConfig(
  name: "example",
  allHosts: @["example.com"],
  containers: @[
    ContainerRef(
      path: "/",
      port: 1234,
      container: newContainer(
        spec = ContainerSpec(
          name: "example",
          image: "nginx:latest",
          containerPort: 80,
          host: "example.com"
        )
      )
    )
  ]
)

let cc = newContainersCollection()

block RemoveOne:
  let tmpDir = createTempDir("","")
  let ncc = newConfigsCollection(cc, dir = tmpDir, useHttps = false)
  ncc.disableOnChange()
  ncc.mkExpected @[]
  let extraFile = tmpDir / "extra.conf"
  extraFile.createFile

  let startingState = waitFor ncc.getWorldState()
  assert len(startingState) == 1
  let changes = waitFor ncc.ensure()
  assert len(changes.added) == 0
  assert len(changes.removed) == 1
  let endState = waitFor ncc.getWorldState()
  assert len(endState) == 0

block CreateOneIdempotent:
  let tmpDir = createTempDir("","")
  let ncc = newConfigsCollection(cc, dir = tmpDir, useHttps = false)
  ncc.disableOnChange()
  ncc.mkExpected @[mockConfig]

  # assert no files
  let startingState = waitFor ncc.getWorldState()
  assert len(startingState) == 0

  let changes = waitFor ncc.ensure()
  assert len(changes.added) == 1
  assert len(changes.removed) == 0
  let endState = waitFor ncc.getWorldState()
  assert len(endState) == 1

  let changes2 = waitFor ncc.ensure()
  assert len(changes2.removed) == 0
  assert len(changes2.added) == 0
  let endState2 = waitFor ncc.getWorldState()
  assert len(endState2) == 1

block ModifyOne:
  let tmpDir = createTempDir("","")
  let ncc = newConfigsCollection(cc, dir = tmpDir, useHttps = false)
  ncc.disableOnChange()
  ncc.mkExpected @[mockConfig]
  let extraFile = tmpDir / mockConfig.filename
  extraFile.createFile

  let startingState = waitFor ncc.getWorldState()
  assert len(startingState) == 1
  let changes = waitFor ncc.ensure()
  assert len(changes.added) == 1
  assert len(changes.removed) == 1
  let endState = waitFor ncc.getWorldState()
  assert len(endState) == 1

block AddsAPIConfig:
  let tmpDir = createTempDir("", "")
  let mockContainersCollection = newContainersCollection()
  mockContainersCollection.mkExpected @[]
  let ncc = newConfigsCollection(mockContainersCollection, dir = tmpDir, useHttps = false)
  ncc.disableOnChange()

  let startingState = waitFor ncc.getWorldState()
  assert len(startingState) == 0
  let changes = waitFor ncc.ensure()
  assert len(changes.added) == 1
  let endState = waitFor ncc.getWorldState()
  assert len(endState) == 1
  


# block RemoveOne:
#   let tmpDir = createTempDir("","")


# block CreateOne
# expected = @[example]
# actual = @[] (empty temp dir)
#
# block removeOne
# expected = @[]
# actual = @[junk]
#
# block modifyOne
# expected = @[example]
# actual = @[example (but incorrect)]
#
