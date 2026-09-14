# Cert Manager CRDs

Let's Encrypt issuer and the `*.letusseng.com` wildcard certificate, solved with Cloudflare DNS-01.

## Install
- run `./scripts/install-traefik.sh` first
- `./scripts/install-cert-manager.sh` creates the `cloudflare-api-token` secret from `CLOUDFLARE_API_TOKEN`
  in `.env` (Zone:DNS:Edit + Zone:Zone:Read on letusseng.com), installs the chart and applies this directory

## How certificates reach apps
One wildcard certificate (`letusseng.com`, `*.letusseng.com`) lives in the `traefik` namespace as
`letusseng-com-tls`. Traefik's default TLSStore serves it (`gitops/traefik/values.yaml`), so every
Ingress on traefik gets HTTPS without a `secretName` or copying secrets between namespaces:
```yaml
  tls:
    - hosts:
        - app.letusseng.com
```

## Issuers
- `letsencrypt`: production, used by the wildcard certificate
- `letsencrypt-staging`: untrusted root but generous rate limits. Point a new Certificate (or a
  solver/DNS change) at it first, then switch `issuerRef` once it issues.

Changing a Certificate's `issuerRef` reissues it automatically, and traefik keeps serving the old
cert until the new one is ready, so don't delete the secret. To force a renewal:
`kubectl cert-manager renew -n traefik letusseng-com` (or `cmctl renew`).

Check what traefik serves (the issuer must not contain `(STAGING)`):
```
openssl s_client -connect 10.0.0.103:443 -servername pihole.letusseng.com </dev/null 2>/dev/null | openssl x509 -noout -issuer -enddate -ext subjectAltName
```
