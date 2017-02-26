#!/bin/bash
# Ansible Tower, launch job and get stdout back
# Run on Ansible Tower host

if [ -f call.out ]; then
	rm -f call.out
fi

JOB_TEMPLATE_ID=$1
ANSIBLE_SERVER=$2

if [ "$ANSIBLE_SERVER" == "" ]
then 
	echo "Usage: $0 [ANSIBLE_SERVER_FQDN] [JOB_TEMPLATE_ID]"
	exit 1
fi

if ! echo $JOB_TEMPLATE_ID|grep [0-9] >/dev/null
then
	echo "Usage: $0 [ANSIBLE_SERVER_FQDN] [JOB_TEMPLATE_ID]"
	exit 1
fi

curl -s -f -k -H 'Content-Type: application/json' -XPOST --user devops:redhat123 https://localhost/api/v1/job_templates/$JOB_TEMPLATE_ID/launch/ -o call.out

JOB_ID=$(cat call.out|cut -d\" -f5|sed -e 's/://g' -e 's/,//g')
if echo $JOB_ID|grep [0-9] >/dev/null
then
	echo "$(date): Job created successfully. ID: $JOB_ID"
else
	echo "$(date): Error, did not successfully run job."
	exit 1
fi

while true
do
	curl -s -f -k -H 'Content-Type: application/json' -XGET --user devops:redhat123 https://localhost/api/v1/jobs/$JOB_ID/ -o job.status

	if cat job.status|grep "ok=2    changed=0    unreachable=0    failed=0" >/dev/null
	then
		echo "$(date): Job completed OK."
		echo $(date): Job output: $(cat job.status | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'|grep result_stdout|cut -d] -f6|cut -d\" -f4|sed 's/\\//g')
		break
	else
		echo "$(date): Job not yet completed."
		sleep 1
	fi
done

exit 0
