{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "sumologic.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}

{{/*
Kubelet metrics regex

Example Usage:
{{- include "regex.metric.kubelet" . }}

*/}}
{{- define "regex.metric.kubelet" -}}
{{- if .Values.prometheusSpec.kubelet.metricsRegex }}
{{- .Values.prometheusSpec.kubelet.metricsRegex }}
{{- else -}}
(?:kubelet_docker_operations_errors(?:|_total)|kubelet_(?:docker|runtime)_operations_duration_seconds_(?:count|sum)|kubelet_running_(?:container|pod)(?:_count|s)|kubelet_(:?docker|runtime)_operations_latency_microseconds(?:|_count|_sum))
{{- end -}}
{{- end -}}

{{/*
Cadvisor container metrics regex

Example Usage:
{{- include "regex.metric.cadvisor.container" . }}

*/}}
{{- define "regex.metric.cadvisor.container" -}}
{{- if .Values.prometheusSpec.cadvisor.containerMetricsRegex }}
{{ .Values.prometheusSpec.cadvisor.containerMetricsRegex }}
{{- else -}}
(?:{{- include "regex.metric.cadvisor._container" . }})
{{- end -}}
{{- end -}}

{{- define "regex.metric.cadvisor._container" -}}
container_cpu_usage_seconds_total|container_memory_working_set_bytes|container_memory_usage_bytes|container_fs_usage_bytes|container_fs_limit_bytes
{{- end -}}

{{/*
Cadvisor container aggregate metrics regex

Example Usage:
{{- include "regex.metric.cadvisor.aggregate" . }}

*/}}
{{- define "regex.metric.cadvisor.aggregate" -}}
{{- if .Values.prometheusSpec.cadvisor.aggregateMetricsRegex }}
{{ .Values.prometheusSpec.cadvisor.aggregateMetricsRegex }}
{{- else -}}
(?:{{- include "regex.metric.cadvisor._aggregate" . }})
{{- end -}}
{{- end -}}

{{- define "regex.metric.cadvisor._aggregate" -}}
container_network_receive_bytes_total|container_network_transmit_bytes_total
{{- end -}}

{{/*
Cadvisor all container metrics regex

Example Usage:
{{- include "regex.metric.cadvisor.all" . }}

*/}}
{{- define "regex.metric.cadvisor.all" -}}
{{ printf "(?:%s|%s)" ( include "regex.metric.cadvisor._container" . ) ( include "regex.metric.cadvisor._aggregate" . ) }}
{{- end -}}

{{/*
KubeStateMetrics metrics regex

Example Usage:
{{- include "regex.metric.kubeStateMetrics" . }}

*/}}
{{- define "regex.metric.kubeStateMetrics" -}}
{{- if .Values.prometheusSpec.kubeStateMetrics.metricsRegex }}
{{- .Values.prometheusSpec.kubeStateMetrics.metricsRegex }}
{{- else -}}
(?:kube_statefulset_status_observed_generation|kube_statefulset_status_replicas|kube_statefulset_replicas|kube_statefulset_metadata_generation|kube_daemonset_status_current_number_scheduled|kube_daemonset_status_desired_number_scheduled|kube_daemonset_status_number_misscheduled|kube_daemonset_status_number_unavailable|kube_deployment_spec_replicas|kube_deployment_status_replicas_available|kube_deployment_status_replicas_unavailable|kube_node_info|kube_node_status_allocatable|kube_node_status_capacity|kube_node_status_condition|kube_pod_container_info|kube_pod_container_resource_requests|kube_pod_container_resource_limits|kube_pod_container_status_ready|kube_pod_container_status_terminated_reason|kube_pod_container_status_restarts_total|kube_pod_status_phase)
{{- end -}}
{{- end -}}

{{/*
NodeExporter metrics regex

Example Usage:
{{- include "regex.metric.nodeExporter" . }}

*/}}
{{- define "regex.metric.nodeExporter" -}}
{{- if .Values.prometheusSpec.nodeExporter.metricsRegex }}
{{- .Values.prometheusSpec.nodeExporter.metricsRegex }}
{{- else -}}
(?:node_load1|node_load5|node_load15|node_cpu_seconds_total|node_disk_io_time_weighted_seconds_total|node_disk_io_time_seconds_total|node_vmstat_pgpgin|node_vmstat_pgpgout|node_memory_MemFree_bytes|node_memory_Cached_bytes|node_memory_Buffers_bytes|node_memory_MemTotal_bytes|node_network_receive_drop_total|node_network_transmit_drop_total|node_network_receive_bytes_total|node_network_transmit_bytes_total|node_filesystem_avail_bytes|node_filesystem_size_bytes)
{{- end -}}
{{- end -}}

{{- define "kubeStateMetrics.namespace" -}}
{{- if .Values.prometheusSpec.kubeStateMetrics.namespace }}
{{- .Values.prometheusSpec.kubeStateMetrics.namespace }}
{{- else }}
{{ fail "\nPlease provide .Values.prometheusSpec.kubeStateMetrics.namespace to indicate where Prometheus can scrape kube-state-metrics" }}
{{- end -}}
{{- end -}}

{{- define "nodeExporter.namespace" -}}
{{- if .Values.prometheusSpec.nodeExporter.namespace }}
{{- .Values.prometheusSpec.nodeExporter.namespace }}
{{- else }}
{{ fail "\nPlease provide .Values.prometheusSpec.nodeExporter.namespace to indicate where Prometheus can scrape node-exporter" }}
{{- end -}}
{{- end -}}

# ------------------------------------------------------------------------------

{{- define "prometheus.remoteWrite" -}}
{{- include "prometheus._defaultRemoteWrite" . }}
{{- if .Values.prometheusSpec.additionalRemoteWrite }}
{{ toYaml .Values.prometheusSpec.additionalRemoteWrite }}
{{- end }}
{{- end -}}

{{- define "prometheus._defaultRemoteWrite" -}}
# kube state metrics
- url: http://$(COLLECTION_SERVICE).$(COLLECTION_NAMESPACE).svc.cluster.local:9888/prometheus.metrics.state
  remoteTimeout: 5s
  writeRelabelConfigs:
    - action: keep
      regex: kube-state-metrics;{{ include "regex.metric.kubeStateMetrics" . }}
      sourceLabels: [job,__name__]
# kubelet metrics
- url: http://$(COLLECTION_SERVICE).$(COLLECTION_NAMESPACE).svc.cluster.local:9888/prometheus.metrics.kubelet
  remoteTimeout: 5s
  writeRelabelConfigs:
    - action: keep
      regex: kubelet;{{ include "regex.metric.kubelet" . }}
      sourceLabels: [job,__name__]
# cadvisor metrics
- url: http://$(COLLECTION_SERVICE).$(COLLECTION_NAMESPACE).svc.cluster.local:9888/prometheus.metrics.container
  remoteTimeout: 5s
  writeRelabelConfigs:
    - action: keep
      regex: kubelet;{{ include "regex.metric.cadvisor.all" . }}
      sourceLabels: [job,__name__]
# node-exporter metrics
- url: http://$(COLLECTION_SERVICE).$(COLLECTION_NAMESPACE).svc.cluster.local:9888/prometheus.metrics.node
  remoteTimeout: 5s
  writeRelabelConfigs:
    - action: keep
      regex: node-exporter;{{ include "regex.metric.nodeExporter" . }}
      sourceLabels: [job,__name__]
{{- end -}}

# ------------------------------------------------------------------------------
{{/*
Prometheus default spec

Example Usage:
{{- include "prometheus.defaultSpec" . }}

*/}}
{{- define "prometheus.defaultSpec" -}}
version: v2.22.1
containers:
- env:
  - name: COLLECTION_SERVICE
    valueFrom:
      configMapKeyRef:
        key: fluentdMetrics
        name: sumologic-configmap
  - name: COLLECTION_NAMESPACE
    valueFrom:
      configMapKeyRef:
        key: fluentdNamespace
        name: sumologic-configmap
  name: config-reloader
enableAdminAPI: false
listenLocal: false
logFormat: logfmt
logLevel: info
paused: false
podMonitorSelector: {}
portName: web
serviceAccountName: {{ include "sumologic.fullname" . }}-prometheus
replicas: 1

{{- if .Values.prometheusSpec.resources }}
resources:
{{ toYaml .Values.prometheusSpec.resources | indent 2 }}
{{- end }}

scrapeInterval: {{ include "prometheus.scrapeInterval" . }}
retention: {{ include "prometheus.retention" . }}
routePrefix: /

{{- if .Values.prometheusSpec.walCompression }}
walCompression: {{ .Values.prometheusSpec.walCompression }}
{{- end }}

securityContext:
  fsGroup: 2000
  runAsNonRoot: true
  runAsUser: 1000

{{- if .Values.prometheusSpec.storageSpec }}
storage:
{{ toYaml .Values.prometheusSpec.storageSpec | indent 2 }}
{{- end }}

{{- end -}}
# ------------------------------------------------------------------------------

{{- define "prometheus.scrapeInterval" -}}
{{- if .Values.prometheusSpec.scrapeInterval }}
{{- .Values.prometheusSpec.scrapeInterval }}
{{- else }}
"60s"
{{- end }}
{{- end }}

{{- define "prometheus.retention" -}}
{{- if .Values.prometheusSpec.retention }}
{{- .Values.prometheusSpec.retention }}
{{- else }}
6h
{{- end }}
{{- end }}