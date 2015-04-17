#!/bin/sh

if [ -z "$1" -o "$1" = "-h" -o "$1" = "--help" ]; then
    echo "Usage: `basename $0` [FQDN1] [[...FQDNX]]"
    exit 1
fi

# See if there is an existing CA directory, prompt to nuke it
if [ -d "CA" ]; then
	/bin/echo -n "### A 'CA' directory already exists.  Delete it and start over (y/N)? "
	read confirm
	if [ "$confirm" = 'y' -o "$confirm" = "Y" ]; then
		rm -Rf ./CA
        mkdir CA
	elif [ -e CA/cacert.pem ]; then
		# This script can be used with an existing CA to build server certs
		/bin/echo -n "### Use the existing CA/cacert.pem (Y/n)? "
		read confirm
		if [ "$confirm" != 'y' -a "$confirm" != "Y" ]; then
			echo "### Please move or remove the existing CA directory"
			echo "    and re-run this script."
			exit 1
		fi
	else
		echo "### No existing CA/cacert.pem file found.  Please move or remove"
		echo "    the existing CA directory and re-run this script."
		exit 1
	fi
else
    mkdir CA
fi

cd CA

echo -n "### Building stunnel-ssl.cnf..."
cat <<EOF > stunnel-ssl.cnf
HOME                    = .
RANDFILE                = \$ENV::HOME/.rnd
oid_section             = new_oids
[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = US
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_default     = Colorado
localityName                    = Locality Name (eg, city)
localityName_default            = Fort Collins
0.organizationName              = Organization Name (eg, company)
0.organizationName_default      = HP
organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_default  = Monasca
commonName                      = Common Name (e.g. server FQDN or YOUR name)
commonName_max                  = 64
subjectAltName                  = Subject Alternate Name
subjectAltName                  = 64
[ req_attributes ]
challengePassword               = A challenge password
challengePassword_min           = 4
challengePassword_max           = 20
unstructuredName                = An optional company name
[ new_oids ]
tsa_policy1 = 1.2.3.4.1
tsa_policy2 = 1.2.3.4.5.6
tsa_policy3 = 1.2.3.4.5.7
[ ca ]
default_ca      = CA_default              # The default CA section
[ CA_default ]
dir             = ./                      # Where everything is kept
certs           = \$dir/certs             # Where the issued certs are kept
crl_dir         = \$dir/crl               # Where the issued crl are kept
database        = \$dir/index.txt         # Database index file
unique_subject = no                       # Set to 'no' to allow creation of
                                          # several ctificates with same subject
new_certs_dir   = \$dir                   # Default place for new certs.
certificate     = \$dir/cacert.pem        # The CA certificate
serial          = \$dir/serial            # The current serial number
crlnumber       = \$dir/crlnumber         # The current crl number,
                                          # comment out to leave a V1 CRL
crl             = \$dir/crl.pem           # The current CRL
private_key     = \$dir/private/cakey.pem # The private key
RANDFILE        = \$dir/private/.rand     # Private random number file
x509_extensions = usr_cert                # The extentions to add to the cert
name_opt        = ca_default              # Subject Name options
cert_opt        = ca_default              # Certificate field options
default_days    = 3650                    # How long to certify for
default_crl_days= 30                      # How long before next CRL
default_md      = sha1                    # Use public key default MD
preserve        = no                      # Keep passed DN ordering
policy          = policy_match
[ policy_match ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = match
commonName              = supplied
subjectAltName          = optional
[ policy_anything ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
subjectAltName          = optional
[ req ]
default_bits            = 2048
default_keyfile         = privkey.pem
distinguished_name      = req_distinguished_name
attributes              = req_attributes
x509_extensions = v3_ca                   # Extensions added to self-signed cert
string_mask = utf8only
[ usr_cert ]
basicConstraints=CA:FALSE
nsComment                       = "OpenSSL Generated Certificate"
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:true
[ crl_ext ]
authorityKeyIdentifier=keyid:always
[ proxy_cert_ext ]
basicConstraints=CA:FALSE
nsComment                       = "OpenSSL Generated Certificate"
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
proxyCertInfo=critical,language:id-ppl-anyLanguage,pathlen:3,policy:foo
[ tsa ]
default_tsa = tsa_config1                  # The default TSA section
[ tsa_config1 ]
dir             = ./demoCA                 # TSA root directory
serial          = \$dir/tsaserial          # Current serial number (mandatory)
crypto_device   = builtin                  # OpenSSL engine to use for signing
signer_cert     = \$dir/tsacert.pem        # The TSA signing certificate
                                           # (optional)
certs           = \$dir/cacert.pem         # Cert. chain to include in reply
                                           # (optional)
signer_key      = \$dir/private/tsakey.pem # The TSA private key (optional)
default_policy  = tsa_policy1              # Policy if request did'nt specify it
                                           # (optional)
other_policies  = tsa_policy2, tsa_policy3 # acceptable policies (optional)
digests         = sha1                     # Acceptable message digests (req'd)
accuracy        = secs:1, millisecs:500, microsecs:100  # (optional)
clock_precision_digits  = 0                # number of digits after dot. (opt.)
ordering                = yes              # Is ordering defined for timestamps?
                                           # (optional, default: no)
tsa_name                = yes              # Include the TSA name in the reply?
                                           # (optional, default: no)
ess_cert_id_chain       = no               # Include the ESS cert ID chain?
                                           # (optional, default: no)
EOF

echo done

echo
echo "### Creating CA cert.  Enter pass phrase and Common Name when prompted."
openssl req -new -x509 -days 3650 -extensions v3_ca -keyout cakey.pem -out cacert.pem -config stunnel-ssl.cnf
touch index.txt
echo 01 > serial

echo
echo "### Beginning certificate generation for these servers: $*"
echo

for server in $*; do
    for type in zookeeper_server zookeeper_client kafka_server kafka_client; do
        echo "### [$server] Creating CSR for $type"
        echo "### Hit Enter 5 times, then '$server' for Common Name."
        openssl req -new -days 365 -nodes -config stunnel-ssl.cnf -out certreq.pem -keyout $type.key
        echo
        echo "### [$server] Signing CSR for $type.  Enter passphrase and 'y' twice."
        openssl ca -config stunnel-ssl.cnf -keyfile cakey.pem -in certreq.pem -out $type.pem
        echo "### [$server] Creating ${server}_${type}_combined.pem"
        cat $type.key $type.pem > ${server}_${type}_combined.pem
        chmod 600 ${server}_${type}_combined.pem
        echo
    done
    echo
done

