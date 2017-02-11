#!/bin/bash
# Generate self signed SSL cert with multiple IPs

openssl genrsa -des3 -passout pass:x -out server.pass.key 2048
openssl rsa -passin pass:x -in server.pass.key -out server.key
rm server.pass.key

openssl req -new -key server.key -out server.csr -subj '/C=US/ST=New York/L=New York/O=OpenShift/OU=Sel Signed/CN=ocpatestmaster.northeurope.cloudapp.azure.com/emailAddress=no-reply@localhost.localdomain/subjectAltName=IP.1=192.168.1.4,IP.2=192.168.1.5,IP.3=192.168.1.6'

openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

