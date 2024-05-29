#!/usr/bin/env bash

# generate private key
openssl genrsa -out key.pem 2048
openssl ecparam -name prime256v1 -genkey -noout -out key.pem

# create CSR configuration
cat <<'EOF' >req.conf
[req]
default_bits              = 2048
req_extensions            = extension_requirements
distinguished_name        = dn_requirements
prompt                    = no

[extension_requirements]
basicConstraints          = CA:FALSE
keyUsage                  = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName            = @sans_list

[dn_requirements]
countryName               = DE
stateOrProvinceName       = Berlin
localityName              = Berlin
0.organizationName        = Organization Name
organizationalUnitName    = Organizational Unit Name
commonName                = grpc.example.internal
emailAddress              = grpc@example.com

[sans_list]
DNS.1                     = grpc.example.internal

EOF

# generate CSR
openssl req -new -key key.pem \
    -out req.csr \
    -config req.conf

# generate self-signed cert
openssl x509 -req \
    -signkey key.pem \
    -in req.csr \
    -out grpc.cert \
    -extfile req.conf \
    -extensions extension_requirements \
    -days 365

# upload to GCP
gcloud compute ssl-certificates create grpc-self-signed \
    --certificate=grpc.cert \
    --private-key=key.pem \
    --region=europe-west1
