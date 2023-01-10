import
    ./collection,
    ./config,
    ./container,
    ./docker,
    asyncdispatch,
    sugar

type
  ContainersCollection* = ref object of ManagedCollection[Container, DContainer]
    dir: string


proc newContainersCollection*(dir = config.containerDir):  ContainersCollection =
  proc getExpected(): Future[seq[Container]] {.async.} =
    return getContainerConfigs(dir)

  proc getWorldState(): Future[seq[DContainer]] {.async.} =
    return getContainers()

  ContainersCollection(
    dir: dir,
    getExpected: getExpected,
    getWorldState: getWorldState,
    matches: (c: Container, dc: DContainer) => c.matches(dc),
    remove: removeContainer,
    create: createContainer
  )