# casc-bundle-lib

A Helm library chart that renders [CloudBees CI](https://docs.cloudbees.com/docs/cloudbees-ci/latest/) CasC bundles as Kubernetes ConfigMaps.

All bundle logic lives in the library. Consumer charts supply only content files and a `values.yaml` — no template authoring required.

## Repository layout

```
charts/casc-bundle-lib/       # the library chart (type: library)
  Chart.yaml
  templates/
    _casc_bundle.tpl          # all rendering logic, exported as casc-bundle.configmap
examples/
  chart/casc-bundle/          # single example consumer chart — copy this as a starting point
    Chart.yaml
    templates/
      configmap.yaml          # {{- include "casc-bundle.configmap" . }}
    content/
      jcasc/jenkins.yaml
      plugins/plugins-oc.yaml
      plugins/plugins-mc.yaml
      items/team-folder.yaml
    tests/                    # helm-unittest test suite
    values.yaml               # commented skeleton
  values-oc.yaml              # Operations Center variant
  values-mc.yaml              # Managed controller variant
  README.md                   # examples walkthrough
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
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
```

### Running tests

The test suite targets the example chart. Because the library is not yet published, package it locally first:

```bash
helm package charts/casc-bundle-lib -d examples/chart/casc-bundle/charts/
helm unittest examples/chart/casc-bundle
```

The first run generates `tests/__snapshots/` — commit those files. Subsequent runs diff against them.

### Linting

```bash
helm lint charts/casc-bundle-lib
helm lint examples/chart/casc-bundle -f examples/chart/values-oc.yaml
```

## Releasing

Create a GitHub release tagged `vX.Y.Z`. The [release workflow](.github/workflows/release.yaml) will:

1. Package `charts/casc-bundle-lib` at the tag's version
2. Push the OCI artifact to `ghcr.io/sboardwell/charts/casc-bundle-lib:X.Y.Z`

The [CI workflow](.github/workflows/ci.yaml) runs lint and the full test suite on every push and pull request.
