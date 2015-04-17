# Monasca-Stunnel
Adds encryption around Kafka and Zookeeper using stunnel

## Tags
- stunnel

## Overview
The monasca-stunnel role works by inserting itself between kafka servers and clients,
and zookeeper servers and clients, thus encrypting communications between them.

Before:
```
KAFKA-CLIENT -->--> KAFKA-SERVER:9092

ZOOKEEPER-CLIENT -->--> ZOOKEEPER-SERVER:2181
```

After:
```
KAFKA-CLIENT --> client-stunnel:29092 -->--> server-stunnel:19092 --> KAFKA-SERVER:9092


ZOOKEEPER-CLIENT --> client-stunnel:22181 -->--> server-stunnel:12181 --> ZOOKEEPER-SERVER:2181
```

where `-->` is a local connection and `-->-->` could be either local or remote.

The client stunnel resides locally on Kafka/Zookeeper clients, and the server
stunnel resides locally on Kafka/Zookeeper servers.  They are activated using
the `enable_stunnel` JSON object on a node-by-node basis (see **Configuration** below)

## Requirements
### Variables
- `kafka_hosts` - comma-delimited list of host:port pairs
- `zookeeper_hosts` - comma-delimited list of host:port pairs
- `kafka_listen_address` - IP address to which the Kafka server will bind, if also used by the kafka role

### Certificates
A signed certificate for each kafka server, kafka client, zookeeper server, and
zookeeper client on each host must exist prior to running this role.  There is
a script that may be used to generate self-signed certificates suitable for
testing in `files/stunnel_build_test_certs.sh`

```
cd files/
./stunnel_build_test_certs.sh server1.domain.net server2.domain.net server3.domain.net
```
This script builds a self-signed Certificate Authority along with signed kafka/zookeeper
client/server certs for each specified host.

### Configuration
The following JSON object must exist for each host where zookeeper and/or kafka
is used (servers and clients) with the boolean values configured accordingly:
```
enable_stunnel:
  kafka_server: false
  kafka_client: false
  zookeeper_server: false
  zookeeper_client: false
```

The monasca-stunnel role needs to be included _before_ kafka or zookeeper roles 
are loaded, as monasca-stunnel will transparently alter the configuration used
by kafka and zookeeper in order to insert itself between clients and servers.
If `kafka_listen_address` is set in the kafka role, it should also be set in
the monasca-stunnel role.
```
- {role: monasca-stunnel, kafka_listen_address: "{{mini_mon_host}}", tags: [stunnel]}
```
or, if `kafka_listen_address` is not used:
```
- {role: monasca-stunnel, tags: [stunnel]}
```

