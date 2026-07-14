# ================================================================
# HashiCorp Vault Server Configuration
# Storage: Integrated Raft | TLS: Let's Encrypt / Self-Signed
# ================================================================

# Listener - HTTPS (API & UI)
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/ssl/fullchain.pem"
  tls_key_file  = "/vault/ssl/privkey.pem"

  # Bật telemetry cho monitoring (Prometheus)
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# Storage - Integrated Raft (không cần Consul)
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-node-1"

  # Performance tuning
  performance_multiplier = 1
}

# Cluster address (dùng cho multi-node Raft, luôn cần cấu hình)
cluster_addr = "https://vault.cloudsb.space:8201"
api_addr     = "https://vault.cloudsb.space:8200"

# Bật Web UI
ui = true

# Logging
log_level = "info"
log_file  = "/vault/logs/vault.log"

# Disable mlock (Docker dùng IPC_LOCK thay thế)
disable_mlock = true

# Telemetry (cho Prometheus/Grafana)
telemetry {
  disable_hostname          = true
  prometheus_retention_time = "24h"
}
