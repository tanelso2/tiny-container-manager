import
  ../cert,
  ../config,
  ../container,
  ../shell_utils,
  asyncdispatch,
  asyncfile,
  options,
  os,
  sequtils,
  strformat,
  strutils,
  sugar,
  nim_utils/files,
  nim_utils/logline

type
  ContainerRef* = ref object of RootObj
    path*: string
    port*: int
    container*: Container
  NginxConfig* = ref object of RootObj
    name*: string
    allHosts*: seq[string]
    containers*: seq[ContainerRef]

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

proc getInstalledCert(target: NginxConfig): Future[Option[Cert]] {.async.} =
  let certs = await getAllCertbotCerts()
  let matches = certs.filterIt(certMatches(target, it))
  if len(matches) < 1:
    return none(Cert)
  else:
    return some(matches[0])

proc isCertValid*(target: NginxConfig): Future[bool] {.async.} =
  let x = await target.getInstalledCert()
  return x.isSome and x.get().exp.valid

proc cert(x: NginxConfig): Future[Option[Cert]] {.async.} =
  return await getInstalledCert(x)

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

proc compare*(expected: NginxConfig, actual: ActualNginxConfig, useHttps: bool): bool =
  if actual.fileType != ftFile:
    return false
  if actual.filename != expected.filename:
    return false
  var expectedContents: string
  if useHttps:
    let valid = waitFor expected.isCertValid()
    if not valid:
      # If the cert is not valid, consider this a non-valid deployment
      return false
    let cert = (waitFor expected.cert).get()
    expectedContents = expected.nginxConfigWithCert(cert)
  else:
    expectedContents = expected.simpleNginxConfig()
  let contents = readFile(actual.path)
  return contents == expectedContents

proc requestCert*(target: NginxConfig) {.async.} =
  let allHosts = target.allHosts
  let hostCmdLine = allHosts.map((x) => fmt"-d {x}").join(" ")
  let certbotCmd = fmt"certbot certonly --nginx -n --keep {hostCmdLine} --email {config.email} --agree-tos"
  echo certbotCmd
  echo await certbotCmd.asyncExec()

proc createInDir*(target: NginxConfig, dir: string, useHttps: bool) {.async.} =
  logInfo fmt"Creating {target.name}"
  var contents: string
  if useHttps and (await target.isCertValid):
    let cert = (await target.cert).get()
    contents = target.nginxConfigWithCert(cert)
  else:
    contents = target.simpleNginxConfig()
  let filename = dir / target.filename
  await createFileAsync(filename)
  let f = openAsync(filename, mode = fmWrite)
  await f.write(contents)
  f.close()