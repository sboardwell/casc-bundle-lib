# casc-bundle-lib

A Helm library chart that renders [CloudBees CI](https://docs.cloudbees.com/docs/cloudbees-ci/latest/) CasC bundles as Kubernetes ConfigMaps.

All bundle logic lives in the library. Consumer charts supply only content files and a `values.yaml` — no template authoring required.

## Repository layout

```
charts/casc-bundle-lib/       # the library chart (type: library)
  Chart.yaml
  templates/
    _casc_bundle.tpl          # all rendering logic, exported as casc-bundle.configmap
charts/casc-bundle-lib-test-consumer/  # internal test consumer (never published)
  tests/                     # helm-unittest test suite (validation + snapshots)
examples/
  casc-bundle/               # example consumer chart — copy this as a starting point
    Chart.yaml
    templates/
      configmap.yaml         # {{- include "casc-bundle.configmap" . }}
    content/
      jcasc/common/jenkins.yaml
      jcasc/oc/casc-oc.yaml
      plugins/plugins-oc.yaml
      plugins/plugins-mc.yaml
      partials/plugins-base.yaml
      items/team-folder.yaml
    values.yaml              # commented skeleton
  services/oc/values.yaml    # Operations Center variant
  services/mc/values.yaml    # Managed controller variant
  README.md                  # examples walkthrough
```

## Using the library

### 1. Declare the dependency

```yaml
# Chart.yaml
apiVersion: v2
name: my-oc-bundle
type: application
version: 0.1.0
dependencies:
  - name: casc-bundle-lib
    version: "0.1.0"
    repository: "oci://ghcr.io/sboardwell/charts"
```

### 2. Create a one-line template

```yaml
# templates/configmap.yaml
{{- include "casc-bundle.configmap" . }}
```

### 3. Add content files and configure values

```
my-oc-bundle/
  content/
    jcasc/jenkins.yaml
    plugins/plugins-oc.yaml
  values.yaml
```

```yaml
# values.yaml
bundleRevision: "1"
bundleDescription: "Operations Center bundle"

sections:
  jcasc:
    - content/jcasc/*.yaml
  plugins:
    - content/plugins/plugins-oc.yaml
```

### 4. Resolve the dependency and render

```bash
helm dependency update .
helm template my-release . [-f overrides.yaml]
```

## values.yaml reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `bundleRevision` | yes | — | Bundle version string; bump to trigger a reload in CloudBees CI |
| `bundleId` | no | `.Release.Name` | Bundle ID written into `bundle.yaml` |
| `bundleDescription` | no | `""` | Bundle description |
| `templateVars` | no | `{}` | Variables injected into every rendered content file |
| `sections` | no | `{}` | Map of section name → list of entries (see below) |

### Section names

Valid section names, rendered in this order: `jcasc`, `plugins`, `catalog`, `rbac`, `items`, `variables`.

### Entry forms

**Glob string** — every matched file is rendered with global `templateVars`:

```yaml
sections:
  jcasc:
    - content/jcasc/*.yaml
```

**Template dict** — renders a single file with per-entry `templateVars` merged on top of (and overriding) global `templateVars`. `target` is required when the same template is reused across multiple entries:

```yaml
sections:
  items:
    - template: content/items/team-folder.yaml
      target: items-platform.yaml
      templateVars:
        teamKey: "platform"
        teamDisplayName: "Platform"
    - template: content/items/team-folder.yaml
      target: items-card-banking.yaml
      templateVars:
        teamKey: "card-banking"
        teamDisplayName: "Card Banking"
```

All resolved output filenames across every section must be globally unique. `bundle.yaml` is reserved.

## Partials

`.Files` is injected into the template context, so any content file can include a shared snippet:

```yaml
# content/plugins/plugins-oc.yaml
plugins:
{{ .Files.Get "content/partials/plugins-common.yaml" | indent 2 }}
  - id: operations-center-cloud
```

If the partial itself contains Go template syntax, wrap it with `tpl`:

```yaml
{{ tpl (.Files.Get "content/partials/my-snippet.yaml") . }}
```

## Development

### Prerequisites

- Helm ≥ 3.8
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin (local only — CI uses Docker, see below)

Install from a release tarball to avoid the verification prompt:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest/releases/download/v0.6.2/helm-unittest.tgz
```

### Running tests locally

The test suite lives in `charts/casc-bundle-lib-test-consumer/`. `make test` syncs the
local library into its `charts/` directory and runs helm-unittest in one step:

```bash
make test
```

`make test/deps` runs the sync alone (useful after editing the library before a manual
`helm template` check). Snapshot files under `tests/__snapshot__/` are committed — the
first run after a rendering change will update them; commit the result.

### Running tests in CI

CI uses Docker rather than the plugin to avoid verification issues and pin an exact version:

```bash
docker run --rm -v $(pwd):/apps helmunittest/helm-unittest:4.3.0-1.2.0 \
  --output-type junit \
  --output-file junit.xml \
  --strict \
  --file 'tests/*.yaml' \
  charts/casc-bundle-lib-test-consumer
```

Test results are published to the GitHub Actions summary via `mikepenz/action-junit-report`.

### Linting

```bash
make lint           # library chart only
make -C examples lint/oc lint/mc  # example chart against both values files
```

## Releasing

Create a GitHub release tagged `vX.Y.Z`. The [release workflow](.github/workflows/release.yaml) will:

1. Package `charts/casc-bundle-lib` at the tag's version
2. Push the OCI artifact to `ghcr.io/sboardwell/charts/casc-bundle-lib:X.Y.Z`

The [CI workflow](.github/workflows/ci.yaml) runs lint and the full test suite on every push and pull request.
