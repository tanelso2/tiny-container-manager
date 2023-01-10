import
    ./conffile,
    ../config,
    ../container

proc apiConfig*(): NginxConfig =
  let rootCon = ContainerRef(path: "/",
                             port: config.tcmApiPort,
                             container: Container())
  NginxConfig(
    name: "tcm_api",
    allHosts: @[config.tcmHost],
    containers: @[rootCon]
  )