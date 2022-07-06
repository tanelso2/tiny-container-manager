import 
    std/re,
    unittest,
    strutils,
    strformat,
    sequtils,
    tiny_container_manager/cert

let exampleOutput = """
  Certificate Name: staging.thomasnelson.me
    Serial Number: 41f9e82cd6bd25dea4a3f998c3ca84e6eb5
    Key Type: RSA
    Domains: staging.thomasnelson.me
    Expiry Date: 2022-03-17 09:18:15+00:00 (INVALID: EXPIRED)
    Certificate Path: /etc/letsencrypt/live/staging.thomasnelson.me/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/staging.thomasnelson.me/privkey.pem
  Certificate Name: thomasnelson.me
    Serial Number: 4acc610091b16d1bac1ae91060d68dbc01c
    Key Type: RSA
    Domains: thomasnelson.me www.thomasnelson.me
    Expiry Date: 2022-09-25 15:21:57+00:00 (VALID: 89 days)
    Certificate Path: /etc/letsencrypt/live/thomasnelson.me/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/thomasnelson.me/privkey.pem
"""

suite "Cert suite":
    test "parsing certbot output":
      let res = exampleOutput.findAll(certbotCertRegex)
      check(len(res) == 2)
      let r = parseCerts(exampleOutput)
      check(len(r) == 2)
      let x = r[0]
      check(x.name == "staging.thomasnelson.me")
      echo x.exp.valid
      check(x.privKeyPath == "/etc/letsencrypt/live/staging.thomasnelson.me/privkey.pem")
      let validCerts = r.filterIt(it.exp.valid)
      check(len(validCerts) == 1)
      check(validCerts[0].name == "thomasnelson.me")

