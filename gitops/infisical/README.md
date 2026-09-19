# Infisical

Self-hosted secrets manager at https://infisical.letusseng.com. Apps keep reading plain k8s Secrets
(`existingSecret`); the Infisical secrets operator writes those Secrets from what's stored in
Infisical, and restarts annotated deployments when a value changes.

| app | chart / manifests | what it does |
| --- | --- | --- |
| longhorn-config | `gitops/longhorn-config` | `longhorn-db` storageclass: 1 replica, strict-local, Retain |
| cloudnative-pg | cloudnative-pg 0.29.0 | postgres operator (ns `cnpg-system`) |
| infisical | infisical-standalone 1.11.0 + `manifests/` | server, 3-instance cnpg cluster `infisical-db`, valkey |
| infisical-operator | secrets-operator 0.11.9 + `gitops/infisical-operator/manifests` | InfisicalSecret CRs to k8s Secrets |

Infisical's structure (project `homelab`, env `prod`, folders, the `k8s-operator` machine identity
and its kubernetes auth) is managed by `infra/tf/infisical`. Secret **values** are entered in the ui,
so they never land in tofu state.

## Install
1. Create Infisical's own secrets. They can't live in Infisical, since it needs them to start:
   ```
   INFISICAL_ADMIN_EMAIL=you@example.com ./scripts/bootstrap/bootstrap-infisical-secrets.sh
   ```
   **Save `ENCRYPTION_KEY` and `AUTH_SECRET` in a password manager** (the script prints how).
2. Merge to master. Argo syncs the four apps above. On first sync the chart's autoBootstrap job
   creates the admin user (credentials in `infisical-bootstrap-credentials`), the `homelab` org and
   an instance-admin identity whose token lands in `infisical-bootstrap-secret`.
3. Create the project, folders and operator identity:
   ```
   aws sso login --profile homelab
   tofu -chdir=infra/tf/infisical init
   tofu -chdir=infra/tf/infisical apply
   tofu -chdir=infra/tf/infisical output k8s_operator_identity_id
   ```

## What's synced
| infisical path | k8s Secret | InfisicalSecret |
| --- | --- | --- |
| `/monitoring/grafana` | `monitoring/grafana-admin` | `gitops/grafana/manifests/infisical-secret.yaml` |
| `/monitoring/influxdb` | `monitoring/influxdb-auth` | `gitops/influxdb/manifests/infisical-secret.yaml` |
| `/pihole/admin` | `pihole/pihole-admin` | `gitops/pihole/manifests/infisical-secret.yaml` |
| `/pihole/admin` | `external-dns/pihole-password` | `gitops/external-dns/manifests/infisical-secret.yaml` |

The bootstrap and install scripts still create these for a from-scratch rebuild; the operator takes
them over once infisical is running.

## Consuming a secret
1. Add the folder to `local.folders` in `infra/tf/infisical/local.tf` and apply. The layout is
   `/<namespace>/<app>`.
2. Enter the values in the ui under project `homelab`, env `prod`, at that path.
3. Commit an `InfisicalSecret` next to the app:
   ```yaml
   apiVersion: secrets.infisical.com/v1alpha1
   kind: InfisicalSecret
   metadata:
     name: grafana-admin
     namespace: monitoring
   spec:
     syncConfig:
       resyncInterval: 1m
     authentication:
       kubernetesAuth:
         identityId: <tofu output k8s_operator_identity_id>
         autoCreateServiceAccountToken: true
         serviceAccountRef:
           name: infisical-auth
           namespace: infisical-operator-system
         secretsScope:
           projectSlug: homelab
           envSlug: prod
           secretsPath: /monitoring/grafana
     managedKubeSecretReferences:
       - secretName: grafana-admin
         secretNamespace: monitoring
         creationPolicy: Owner
   ```
   Keys in the folder become keys in the Secret. To rename one, template the reference
   (see `external-dns/pihole-password`):
   ```yaml
         template:
           includeAllSecrets: false
           data:
             EXTERNAL_DNS_PIHOLE_PASSWORD: "{{ .password.Value }}"
   ```
   To restart a deployment on change, annotate it with
   `secrets.infisical.com/auto-reload: "true"`.
4. If the Secret was created by hand before, copy its values into Infisical first, then delete it
   so the operator recreates it as its own.

## Disaster recovery
There are no backups by choice. `infisical-db` runs 3 instances, one per node, each on a
single-replica `longhorn-db` volume, so a lost node or disk is fine and the cnpg primary fails over.
Losing the whole cluster loses the stored values: re-run the install and enter them again. The
PVs are `Retain`, so a pruned PVC or a deleted `Cluster` leaves the data behind in longhorn.

Never re-create `infisical-secrets` with a new `ENCRYPTION_KEY`, because everything already stored
becomes unreadable. The bootstrap script only creates what is missing, so re-running it is safe.

## Notes
- The chart stamps `updatedAt: {{ now }}` on its deployment; the argo app ignores that annotation,
  otherwise every sync would roll the pod.
- The operator talks to `http://infisical.infisical.svc:8080/api`, so syncs keep working when
  pihole or traefik are down.
- No SMTP: inviting users and resetting passwords over email don't work. The admin login is in
  `infisical-bootstrap-credentials`.
