# Repro for clustering over TLS1.2/1.3
This spins up two single-node RabbitMQClusters to demonstrate clustering using a specific TLS version.

## Prerequisites
- bash
- kubectl
- A running k8s cluster, targeted

## Procedure
```bash
./setup.sh
```

## Output
A successful output of the `kubectl exec` commands should look something like this:
```
Verification: OK
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 2048 bit
...
Verify return code: 0 (ok)
---
read:errno=0
SSL3 alert write:warning:close notify
```
This shows that the server has successfully been configured to cluster with the required TLS version.
