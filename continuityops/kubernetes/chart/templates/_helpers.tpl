{{/*
Expand the name of the chart.
*/}}
{{- define "continuityops-lab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "continuityops-lab.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart and app labels.
*/}}
{{- define "continuityops-lab.labels" -}}
helm.sh/chart: {{ include "continuityops-lab.chart" . }}
{{ include "continuityops-lab.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: continuityops
{{- end }}

{{- define "continuityops-lab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "continuityops-lab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "continuityops-lab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "continuityops-lab.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "continuityops-lab.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Immutable image reference — digest pin required.
*/}}
{{- define "continuityops-lab.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $digest := required "image.digest is required (immutable pin)" .Values.image.digest -}}
{{- printf "%s@%s" $repo $digest }}
{{- end }}

{{/*
Secret name for envFrom / env refs.
*/}}
{{- define "continuityops-lab.secretName" -}}
{{- required "secret.secretName is required" .Values.secret.secretName }}
{{- end }}

{{/*
ConfigMap name.
*/}}
{{- define "continuityops-lab.configMapName" -}}
{{- printf "%s-config" (include "continuityops-lab.fullname" .) }}
{{- end }}
