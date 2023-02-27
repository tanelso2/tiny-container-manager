import
    ./api,
    ./conffile,
    ./core,
    ../collection,
    ../container,
    ../container_collection,
    asyncdispatch,
    options,
    sequtils,
    strformat,
    sugar,
    nim_utils/[
        files,
        logline
    ]

type
  NginxConfigsCollection* = ref object of ManagedCollection[NginxConfig, ActualNginxConfig]
    dir*: string
    useHttps: bool

proc getExpectedNginxConfigs(containers: seq[Container]): seq[NginxConfig] =
  result = collect(newSeq):
    for c in containers:
      let rc = c.runningContainer
      # Only enable nginx for running containers
      if rc.isSome():
        let port = rc.get().localPort
        NginxConfig(name: c.name, allHosts: c.allHosts, containers: @[ContainerRef(path: "/", container: c, port: port)])

  result.add(apiConfig())

proc getExpectedNginxConfigs(cc: ContainersCollection): Future[seq[NginxConfig]] {.async.} =
  let cons = await cc.getExpected()
  return getExpectedNginxConfigs(cons)

proc getActualNginxConfigs(dir: string = nginxAvailableDir): seq[ActualNginxConfig] =
  return collectFilesInDir(dir).mapIt(ActualNginxConfig(path: it))

proc getActualNginxEnabled(): seq[string] =
  return collectFilesInDir(nginxEnabledDir)

proc newConfigsCollection*(cc: ContainersCollection, dir: string, useHttps: bool): NginxConfigsCollection =
  proc getWorldState(): Future[seq[ActualNginxConfig]] {.async.} =
    return getActualNginxConfigs(dir)

  proc remove(e: ActualNginxConfig) {.async.} =
    logDebug fmt"Trying to remove nginxConfig {e.path}"
    removePath(e.path)

  proc onChange(cr: ChangeResult[NginxConfig, ActualNginxConfig]) {.async.} =
    await onNginxChange()
    if useHttps:
      for c in cr.added:
        if not await c.isCertValid:
          await c.requestCert()

  proc create(i: NginxConfig) {.async.} =
    logInfo fmt"Trying to create nginxConfig {i.name}"
    await i.createInDir(dir, useHttps)

  NginxConfigsCollection(
    getExpected: () => getExpectedNginxConfigs(cc),
    getWorldState: getWorldState,
    matches: (i: NginxConfig, e: ActualNginxConfig) => compare(i,e, useHttps),
    remove: remove,
    create: create,
    onChange: some(onChange),
    dir: dir
  )