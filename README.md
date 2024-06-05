# gRPC workload on GKE exposed via ILB with Gateway API

Steps to deploy gRPC server service running on GKE behind Google's
Regional internal Application Load Balancer using the Gateway API, self-signed
certificate and Envoy proxy for TLS termination at the backends.

Based on [gke-grpc-gateway-api](https://github.com/stepanstipl/gke-grpc-gateway-api) and using the [Dune quote service](https://www.cncf.io/blog/2021/09/24/kubernetes-ingress-grpc-example-with-a-dune-quote-service/) gRPC image.

## Prerequisites

These steps expect GKE cluster with a Gateway Controller [^1] and internet
access (to download the prebuilt container image). Also the usual `gcloud` CLI
configured for your project and `kubectl` with credentials to your cluster.

## Setup Steps

- Create proxy-only subnet in your network and region
  ```shell
  $ gcloud compute networks subnets create proxy-only-subnet \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --region=<REGION> \
    --network=<NETWORK_NAME> \
    --range=10.129.0.0/23
  ```

- Create self-signed certificate for the ILB and upload to GCP (tweak the CSR configuration in the script as necessary):
  ```shell
  $ ./generate-ilb-self-signed-cert.sh
  ```

- Generate self-signed certificate for the backend
  ```shell
  $ openssl ecparam -genkey -name prime256v1 -noout -out key.pem
  $ openssl req -x509 -new -key key.pem -out cert.pem -days 3650 -subj '/CN=internal'
  ```
  TLS is required both between client and GFE, as well as GFE and backend [^2].

  **Important:** The certificate has to use one of supported signatures
  compatible with BoringSSL, see [^3][^4] for more details. 

- Create K8S Secret with the self-signed cert
  ```shell
  $ kubectl -n grpc create secret tls grpc-envoy-tls \
  --cert=cert.pem \
  --key=key.pem
  ```

- Deploy manifests (change the hostname in `06-httproute.yaml` if necessary):
```shell
  $ kubectl apply -f .
```

- Test using [grpcurl](https://github.com/fullstorydev/grpcurl) (from within the VPC, for example in a pod):
```shell
$ grpcurl -servername grpc.example.internal -insecure 10.2.0.8:443 list
grpc.health.v1.Health
grpc.reflection.v1alpha.ServerReflection
io.kong.developer.quoteservice.QuoteService

$ grpcurl -servername grpc.example.internal -insecure 10.2.0.8:443 io.kong.developer.quoteservice.QuoteService/GetQuote
{
  "message": "Most of the Houses have grown fat by taking few risks. One cannot truly blame them for this; one can only despise them."
}
```

[^1]: https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api
[^2]: https://cloud.google.com/load-balancing/docs/https#using_grpc_with_your_applications
[^3]: https://github.com/grpc/grpc/issues/6722
[^4]: https://groups.google.com/a/chromium.org/forum/#!msg/blink-dev/kWwLfeIQIBM/9chGZ40TCQAJ
