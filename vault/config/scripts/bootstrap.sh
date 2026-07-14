#!/bin/sh

vault policy write flowlog policies/flowlog.hcl
vault write auth/jwt/role/flowlog @roles/flowlog.json
