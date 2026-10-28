{{/*
casc-bundle.configmap — render a CloudBees CI CasC bundle as a ConfigMap.

Expects the standard consumer chart root context (.). The consumer chart must
have a one-line templates/configmap.yaml that calls this template so that
$.Files resolves against the consumer chart's own content/ directory.
*/}}
{{- define "casc-bundle.configmap" -}}
{{- $knownSections := list "jcasc" "plugins" "catalog" "rbac" "items" "variables" }}

{{- /* Validate user-supplied section names */}}
{{- range $section, $_ := .Values.sections }}
{{- if not (has $section $knownSections) }}
{{- fail (printf "unknown bundle section %q — valid: %s" $section (join ", " $knownSections)) }}
{{- end }}
{{- end }}

{{- /* Build the global tpl context: flat templateVars plus Files for partial includes */}}
{{- $globalCtx := merge (dict "Files" $.Files) .Values.templateVars }}

{{- /* Duplicate output-name detection across all sections */}}
{{- $seen := dict }}
{{- range $section := $knownSections }}
{{- range $entry := index $.Values.sections $section }}
{{- if kindIs "string" $entry }}
{{- range $path, $_ := $.Files.Glob $entry }}
{{- $base := base $path }}
{{- if eq $base "bundle.yaml" }}
{{- fail (printf "content file cannot be named bundle.yaml (reserved for the bundle manifest): %s" $path) }}
{{- end }}
{{- if hasKey $seen $base }}
{{- fail (printf "duplicate filename %q: found at %s and %s" $base (index $seen $base) $path) }}
{{- end }}
{{- $_ := set $seen $base $path }}
{{- end }}
{{- else }}
{{- if not $entry.template }}
{{- fail "section entry must have a 'template' field" }}
{{- end }}
{{- $target := $entry.target | default (base $entry.template) }}
{{- if eq $target "bundle.yaml" }}
{{- fail "content file cannot be named bundle.yaml (reserved for the bundle manifest)" }}
{{- end }}
{{- if hasKey $seen $target }}
{{- fail (printf "duplicate filename %q" $target) }}
{{- end }}
{{- $_ := set $seen $target $target }}
{{- end }}
{{- end }}
{{- end }}

apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.configMapName | default .Release.Name }}
  annotations:
    argocd.argoproj.io/sync-options: ServerSideApply=true
  labels:
    helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
    app.kubernetes.io/name: {{ .Chart.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
data:
  bundle.yaml: |
    apiVersion: "2"
    version: {{ required "bundleRevision must be set" .Values.bundleRevision | quote }}
    id: {{ .Values.bundleId | default .Release.Name | quote }}
    description: {{ .Values.bundleDescription | default "" | quote }}
    {{- range $section := $knownSections }}
    {{- $entries := index $.Values.sections $section }}
    {{- if $entries }}
    {{ $section }}:
      {{- range $entry := $entries }}
      {{- if kindIs "string" $entry }}
      {{- range $path, $_ := $.Files.Glob $entry }}
      - {{ base $path }}
      {{- end }}
      {{- else }}
      - {{ $entry.target | default (base $entry.template) }}
      {{- end }}
      {{- end }}
    {{- end }}
    {{- end }}
  {{- range $section := $knownSections }}
  {{- range $entry := index $.Values.sections $section }}
  {{- if kindIs "string" $entry }}
  {{- range $path, $content := $.Files.Glob $entry }}
  {{ base $path }}: |
    {{- tpl ($content | toString) $globalCtx | nindent 4 }}
  {{- end }}
  {{- else }}
  {{- $target := $entry.target | default (base $entry.template) }}
  {{- $entryCtx := merge (dict "Files" $.Files) ($entry.templateVars | default dict) $.Values.templateVars }}
  {{ $target }}: |
    {{- tpl ($.Files.Get $entry.template | toString) $entryCtx | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
