import
    ./conffile,
    ../config,
    ../container

proc apiConfig*(): NginxConfig =
  let rootCon = ContainerRef(path: "/",
                             port: config.tcmApiPort,
                             container: Container())
  NginxConfig(
    # The 00- ensures that this will be loaded by default 
    # when there is not a complete match on the site name
    name: "00-tcm_api",
    allHosts: @[config.tcmHost],
    containers: @[rootCon]
  )