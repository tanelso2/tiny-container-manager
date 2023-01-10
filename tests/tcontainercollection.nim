import
  asyncdispatch,
  os,
  strformat,
  sugar

import
  nim_utils/[
    files,
    logline
  ]

import
  tiny_container_manager/[
    collection,
    container,
    container_collection,
    docker
  ]

import
  test_utils/collection_testing,
  test_utils/container_testing

let testC = testContainer()

if dockerRunning():
  block CleanSlate:
    let cc = newContainersCollection()
    cc.disableOnChange()
    cc.mkExpected @[]

    discard waitFor cc.ensure()
    let cleanState = waitFor cc.getWorldState()
    assert len(cleanState) == 0

  block CreateOneIdempotent:
    let cc = newContainersCollection()
    cc.disableOnChange()
    cc.mkExpected @[testC]

    let startingState = waitFor cc.getWorldState()
    assert len(startingState) == 0

    let changes = waitFor cc.ensure()
    assert len(changes.added) == 1
    assert len(changes.removed) == 0
    let endState = waitFor cc.getWorldState()
    assert len(endState) == 1

    let changes2 = waitFor cc.ensure()
    assert len(changes2.removed) == 0
    assert len(changes2.added) == 0
    let endState2 = waitFor cc.getWorldState()
    assert len(endState2) == 1
  block RemoveOneIdempotent:
    let cc = newContainersCollection()
    cc.disableOnChange()
    cc.mkExpected @[]

    let startingState = waitFor cc.getWorldState()
    # 1 left over from last block
    assert len(startingState) == 1

    let changes = waitFor cc.ensure()
    assert len(changes.added) == 0
    assert len(changes.removed) == 1
    let endState = waitFor cc.getWorldState()
    assert len(endState) == 0

    let changes2 = waitFor cc.ensure()
    assert len(changes2.removed) == 0
    assert len(changes2.added) == 0
    let endState2 = waitFor cc.getWorldState()
    assert len(endState2) == 0

