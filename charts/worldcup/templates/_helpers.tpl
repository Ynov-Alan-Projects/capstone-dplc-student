{{- define "worldcup.name" -}}worldcup{{- end -}}

{{- define "worldcup.labels" -}}
app.kubernetes.io/name: worldcup
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "worldcup.appSelector" -}}
app.kubernetes.io/name: worldcup
app.kubernetes.io/component: app
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "worldcup.dbSelector" -}}
app.kubernetes.io/name: worldcup
app.kubernetes.io/component: db
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
