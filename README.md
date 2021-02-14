1. Copy example.conf and fill with real values.
2. ./mkshard.sh <your conf file>
3. Go to generated folder and into `terraform` folder
4. `terraform init && terraform apply`
5. ssh into on of the nodes and trigger block creation using `rnode --grpc-port 40402 propose`
6. `terraform destroy` once network is not needed.
