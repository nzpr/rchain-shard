source $1
workdir=$NETWORK_ID
rm -Rf $workdir

mkdir $workdir || true
cd $workdir

../scripts/generate-network-files node-files $DOMAIN $NETWORK_ID $NODE_COUNT

mkdir terraform
cp ../GCE/* ./terraform

cat << FOO >> ./terraform/config.tf
variable "credentials_file"   { default = "~/.gcp-account.json" }
variable "tag"         		    { default = "$NETWORK_ID" }
variable "project"        	  { default = "$PROJECT" }
variable "region"             { default = "europe-west1" }
variable "zone"               { default = "europe-west1-b" }
variable "node_count"         { default = "$NODE_COUNT" }
variable "domain"             { default = "$DOMAIN" }
variable "machine_type"       { default = "$INSTANCE" }
variable "disk_size"          { default = 30 }
variable "subnet"             { default = "10.8.0.0/26" }
FOO

cat node-files/*/rnode.conf | grep validator-public-key | \
awk '{print $3}' | \
awk '{print $0 ", 50000000000000"}' >> genesis_bonds.txt

cp ../bootstrap.sh ./
cd node-files

for i in *; do tar -czf $i.tar.gz $i; done
