# Cho phép đọc tất cả secret của project flowlog
path "secret/data/flowlog/*" {
  capabilities = ["read"]
}

# Cho phép đọc metadata của secret (KV v2)
path "secret/metadata/flowlog/*" {
  capabilities = ["read", "list"]
}
