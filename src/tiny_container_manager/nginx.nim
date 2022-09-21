import
  ./cert,
  ./collection,
  ./config,
  ./container,
  ./shell_utils,
  asyncdispatch,
  options,
  os,
  sequtils,
  strformat,
  strutils,
  sugar,
  nim_utils/files,
  nim_utils/logline

const nginxAvailableDir = "/etc/nginx/sites-available"
const nginxEnabledDir = "/etc/nginx/sites-enabled"

type
  ContainerRef* = ref object of RootObj
    path*: string
    port*: int
    container*: Container
  NginxConfig* = ref object of RootObj
    name*: string
    allHosts*: seq[string]
    containers*: seq[ContainerRef]

proc apiConfig(): NginxConfig =
  let rootCon = ContainerRef(path: "/",
                             port: config.tcmApiPort,
                             container: Container())
  NginxConfig(
    name: "tcm_api",
    allHosts: @[config.tcmHost],
    containers: @[rootCon]
  )

proc filename*(target: NginxConfig): string =
  fmt"{target.name}.conf"

proc rootCon(target: NginxConfig): ContainerRef =
  target.containers.filterIt(it.path == "/")[0]

proc host(target: NginxConfig): string =
  return target.allHosts[0]

proc certMatches(target: NginxConfig, cert: Cert): bool =
  let domains = cert.domains
  let host = target.host
  return domains.anyIt(it == host)

proc getInstalledCert(target: NginxConfig): Option[Cert] =
  let certs = getAllCertbotCerts()
  let matches = certs.filterIt(certMatches(target, it))
  if len(matches) < 1:
    return none(Cert)
  else:
    return some(matches[0])

proc isCertValid(target: NginxConfig): bool =
  let x = target.getInstalledCert()
  return x.isSome and x.get().exp.valid

proc cert(x: NginxConfig): Option[Cert] =
  return getInstalledCert(x)

type
  ActualNginxConfig* = ref object of RootObj
    path*: string

proc filename*(target: ActualNginxConfig): string =
  return target.path.extractFilename()

proc fileType(a: ActualNginxConfig): FileType =
  a.path.fileType

proc makeHttpRedirectBlock(host: string): string =
  let x = fmt("""
    if ($host = <host>) {
      return 301 https://$host$request_uri;
    }
  """, '<', '>')
  return x.strip()

proc nginxConfigWithCert(target: NginxConfig, cert: Cert): string =
  let rootCon = target.rootCon
  let name = target.name
  let allHosts = target.allHosts
  let httpRedirectBlocks = allHosts.mapIt(makeHttpRedirectBlock(it)).join("\n\n")
  let hosts = allHosts.join(" ")
  let containerPort = rootCon.port
  let certPath = cert.certPath
  let privKeyPath = cert.privKeyPath
  result = fmt("""
  server {
    listen 80;
    listen [::]:80;

    <httpRedirectBlocks>

    server_name <hosts>;
    return 404;
  }
  server {
    server_name <hosts>;
    location / {
      proxy_pass http://127.0.0.1:<containerPort>;
      proxy_set_header Host $host;
      add_header X-tcm <name> always;
    }

    listen 443 ssl;
    ssl_certificate <certPath>;
    ssl_certificate_key <privKeyPath>;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
  }
  """, '<', '>')

proc simpleNginxConfig*(target: NginxConfig): string =
  let name = target.name
  let port = 80
  let hosts = target.allHosts.join(" ")
  let containerPort = target.rootCon.port
  result = fmt("""
  server {
    listen <port>;
    listen [::]:<port>;

    server_name <hosts>;

    location / {
      proxy_pass http://127.0.0.1:<containerPort>;
      proxy_set_header Host $host;
      add_header X-tcm <name> always;
    }
  }
  """, '<', '>')

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

proc collectFilesInDir*(d: string): seq[string] =
  return collect(newSeq):
    for (_, path) in walkDir(d):
      path

proc getActualNginxConfigs(dir: string = nginxAvailableDir): seq[ActualNginxConfig] =
  return collectFilesInDir(dir).mapIt(ActualNginxConfig(path: it))

proc getActualNginxEnabled(): seq[string] =
  return collectFilesInDir(nginxEnabledDir)


proc compare(expected: NginxConfig, actual: ActualNginxConfig, useHttps: bool): bool =
  if actual.fileType != ftFile:
    return false
  if actual.filename != expected.filename:
    return false
  var expectedContents: string
  if useHttps:
    if not expected.isCertValid():
      # If the cert is not valid, consider this a non-valid deployment
      return false
    let cert = expected.cert.get()
    expectedContents = expected.nginxConfigWithCert(cert)
  else:
    expectedContents = expected.simpleNginxConfig()
  let contents = readFile(actual.path)
  return contents == expectedContents

proc requestCert(target: NginxConfig) {.async.} =
  let allHosts = target.allHosts
  let hostCmdLine = allHosts.map((x) => fmt"-d {x}").join(" ")
  let certbotCmd = fmt"certbot certonly --nginx -n --keep {hostCmdLine} --email {config.email} --agree-tos"
  echo certbotCmd
  echo await certbotCmd.asyncExec()

proc createInDir(target: NginxConfig, dir: string, useHttps: bool) {.async.} =
  logInfo fmt"Creating {target.name}"
  var contents: string
  let certValid = target.isCertValid
  if useHttps and target.isCertValid:
    let cert = target.cert.get()
    contents = target.nginxConfigWithCert(cert)
  else:
    contents = target.simpleNginxConfig()
  let filename = dir / target.filename
  filename.createFile
  filename.writeFile(contents)

proc onNginxChange() {.async.} =
  if checkNginxService():
    logDebug "Reloading nginx"
    await reloadNginx()
  else:
    logDebug "Restarting nginx"
    await restartNginx()

type
  NginxConfigsCollection* = ref object of ManagedCollection[NginxConfig, ActualNginxConfig]
    dir*: string
    useHttps: bool

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
        if not c.isCertValid:
          await c.requestCert()

  proc create(i: NginxConfig) {.async.} =
    logDebug fmt"Trying to create nginxConfig {i.name}"
    await i.createInDir(dir, useHttps)

  NginxConfigsCollection(
    getExpected: () => getExpectedNginxConfigs(cc),
    getWorldState: getWorldState,
    matches: (i: NginxConfig, e: ActualNginxConfig) => compare(i,e, useHttps),
    remove: remove,
    create: create,
    onChange: onChange,
    dir: dir
  )


type
  EnabledLink* = object of RootObj
    filePath*: string
    target*: string
  NginxEnabledFile* = object of RootObj
    filePath*: string
  NginxEnabledCollection* = ref object of ManagedCollection[EnabledLink, NginxEnabledFile]
    enabledDir*: string

proc getExpectedEnabledFiles(ncc: NginxConfigsCollection, enabledDir: string): Future[seq[EnabledLink]] {.async.} =
  let nginxConfs = await ncc.getExpected()
  result = collect(newSeq):
    for n in nginxConfs:
      let filename = n.filename
      let target = ncc.dir / filename
      let filePath = enabledDir / filename
      EnabledLink(filePath: filePath, target: target)

proc getActualEnabledFiles(dir: string): seq[NginxEnabledFile] =
  return collectFilesInDir(dir).mapIt(NginxEnabledFile(filePath: it))

proc compare(e: EnabledLink, f: NginxEnabledFile): bool =
  if e.filePath != f.filePath:
    return false
  let actualFileType = f.filePath.fileType
  if actualFileType != ftSymlink:
    return false
  return f.filePath.expandSymlink == e.target

proc createSymlink(e: EnabledLink) {.async.} =
  logDebug fmt"Creating symlink from {e.filePath} to {e.target}"
  createSymlink(e.target, e.filePath)

proc newEnabledCollection*(ncc: NginxConfigsCollection, enabledDir: string): NginxEnabledCollection =
  proc getWorldState(): Future[seq[NginxEnabledFile]] {.async.} =
    return getActualEnabledFiles(enabledDir)

  proc remove(e: NginxEnabledFile) {.async.} =
    logDebug fmt"Trying to remove nginxConfig {e.filePath}"
    removePath(e.filePath)

  NginxEnabledCollection(
    getExpected: () => getExpectedEnabledFiles(ncc, enabledDir),
    getWorldState: getWorldState,
    matches: compare,
    remove: remove,
    create: createSymlink,
    onChange: (cr: ChangeResult[EnabledLink, NginxEnabledFile]) => onNginxChange(),
    enabledDir: enabledDir
  )
