
#!/bin/bash
# Demo of cluster-to-cluster migration of simple non-persistent app, including state of number of pods.
# sudo@redhat.com, 2017

## Cluster you migrate from
# URL
CLU1=
# TOKEN to user (oc whoami -t)
CLU1_TOKEN=
# Cluster subdomain on which apps get's created 
CLU1_SUBDOMAIN=

## Cluster you migrate to
# URL
CLU2=
# TOKEN to user (oc whoami -t)
CLU2_TOKEN=
# Cluster subdomain on which apps get's created 
CLU2_SUBDOMAIN=

PROJECT=$1

rm -f *yaml

echo "Logging in to $CLU1"
oc login $CLU1 --token=$CLU1_TOKEN --insecure-skip-tls-verify=false >/dev/null 2>&1
echo "Getting $PROJECT data."
oc project $PROJECT >/dev/null 2>&1

# Fetch all stuff, put formated data in files for processes
oc get all >project.tmp 
grep "image(" project.tmp|cut -d'(' -f2|sed 's/)//g' >images.tmp
grep "dc/" project.tmp|awk '{ print $1 }' >dc.tmp
grep "svc/" project.tmp|awk '{ print $1 }' >svc.tmp
grep routes project.tmp |awk '{ print $1 }' >routes.tmp
grep "bc/" project.tmp|awk '{ print $1 }' >bc.tmp
grep "is/" project.tmp|awk '{ print $1 }' >is.tmp

# Fetch YAML data
for item in $(cat dc.tmp); do
	oc get $item -o yaml >$(echo $item|sed 's@/@-@g').yaml
done

for item in $(cat svc.tmp); do
	oc get $item -o yaml >$(echo $item|sed 's@/@-@g').yaml
done

for item in $(cat routes.tmp); do
	oc get $item -o yaml >$(echo $item|sed 's@/@-@g').yaml
done

for item in $(cat bc.tmp); do
	oc get $item -o yaml >$(echo $item|sed 's@/@-@g').yaml
done

for item in $(cat is.tmp); do
	oc get $item -o yaml >$(echo $item|sed 's@/@-@g').yaml
done

echo "Migrating configuration to: $3"
echo "Logging in to $CLU2"
oc login $CLU2 --token=$CLU2_TOKEN --insecure-skip-tls-verify=false >/dev/null 2>&1
echo "Creating project $PROJECT"
oc new-project $PROJECT >/dev/null 2>&1

echo "Creating image stream"
for item in $(ls is-*.yaml); do
	oc create -f $item >/dev/null 2>&1
done

echo "Creating build config"
for item in $(ls bc-*.yaml); do
	oc create -f $item >/dev/null 2>&1
done

echo "Creating deployment configuration."
for item in $(ls dc-*.yaml); do
	oc create -f $item >/dev/null 2>&1
done

echo "Creating services."
for item in $(ls svc-*.yaml); do
	oc create -f $item >/dev/null 2>&1
done

# Change subdomain of route
sed -i "s@$CLU1_SUBDOMAIN@$CLU2_SUBDOMAIN@g" $(ls route*.yaml)

echo "Creating routes."
for item in $(ls route*.yaml); do
	oc create -f $item >/dev/null 2>&1
done

# Start build
echo "Starting build of app on new cluster"
oc start-build $(oc get bc|grep -v NAME|awk '{ print $1 }')

# Cleanup
rm -f *tmp
