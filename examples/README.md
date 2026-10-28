# Examples

This directory contains a single example consumer chart and two values files demonstrating
the two main CloudBees CI bundle types.

```
examples/
  chart/
    casc-bundle/            # reusable consumer chart — copy this as your starting point
      Chart.yaml            # declares casc-bundle-lib as a dependency
      templates/
        configmap.yaml      # one line: {{- include "casc-bundle.configmap" . }}
      content/
        jcasc/jenkins.yaml  # JCasC snippet (used by OC variant)
        plugins/
          plugins-oc.yaml   # OC plugin list
          plugins-mc.yaml   # managed controller plugin list
        items/
          team-folder.yaml  # reusable team folder template
      tests/                # helm-unittest test suite
      values.yaml           # commented skeleton — start here when creating a new bundle
    values-oc.yaml          # Operations Center variant
    values-mc.yaml          # Managed controller variant (multi-team)
```

## Prerequisites

Resolve the chart dependency before rendering:

```bash
helm dependency update examples/chart/casc-bundle
```

## Rendering the examples

**Operations Center bundle:**

```bash
helm template oc examples/chart/casc-bundle -f examples/chart/values-oc.yaml
```

**Managed controller bundle:**

```bash
helm template mc examples/chart/casc-bundle -f examples/chart/values-mc.yaml
```

## How the values files work

Both files target the same chart and the same `content/` directory. Sections, file
selection, and template rendering are all driven by values — no chart changes needed
to switch bundle type.

### Glob entries

A string entry is a glob pattern. Every matched file is rendered into the ConfigMap
using the global `templateVars`:

```yaml
sections:
  jcasc:
    - content/jcasc/*.yaml
  plugins:
    - content/plugins/plugins-oc.yaml
```

### Template dict entries

A dict entry renders a single file and merges per-entry `templateVars` on top of
(and overriding) the global `templateVars`. Use `target` to give the output a unique
name when reusing the same template across multiple entries:

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

### Global templateVars

Variables defined at the root `templateVars` key are available in every rendered
file. Per-entry `templateVars` override root-level keys of the same name:

```yaml
templateVars:
  gitlabUrl: "https://gitlab.example.com"
  licenseKey: "${CI_LICENSE_KEY}"
```

### Partials

Any file in `content/` can include another file as a partial via `.Files.Get`:

```yaml
{{ .Files.Get "content/partials/my-snippet.yaml" }}
```

`.Files` is injected into the template context alongside `templateVars`, so partials
work in both glob-matched files and template dict entries.

## Creating a new bundle

1. Copy `examples/chart/casc-bundle/` to your own chart directory.
2. Add your content files under `content/`.
3. Start from `values.yaml` (the commented skeleton) and fill in `sections`.
4. Run `helm dependency update` then `helm template` to verify the output.
