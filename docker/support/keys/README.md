# Local support JWT keys

These keys are for Docker development only. Production must mount its own
rotatable asymmetric key pair through the deployment secret manager.

Generate the ignored local key pair before starting the Support services:

```sh
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out docker/support/keys/dev-private.pem
openssl pkey -in docker/support/keys/dev-private.pem -pubout -out docker/support/keys/dev-public.pem
chmod 600 docker/support/keys/dev-private.pem
```
