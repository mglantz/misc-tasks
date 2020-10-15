# Name: check_insight.py
#
# Description: Print out summary of detected issues received from Red Hat Insight
# Prereq: latest version of Red Hat Insight installed on the system and system registered to Satelite or cloud.redhat.com.
# Licence: GPL 3.0
#
# Author: Magnus Glantz, sudo@redhat.com, 2020

# Import SYS, OS.path, JSON and RPM modules
import sys 
import os
try:
    import simplejson as json
except ImportError:
    import json
import rpm

# Check for the insights-client package, if it's not installed, nothing will work.
ts = rpm.TransactionSet()
mi = ts.dbMatch( 'name', 'insights-client' )

rpmhit=0
for h in mi:
    if h['name'] == 'insights-client':
        rpmhit=1
        break

if rpmhit == 0:
    print('Unknown: Package insights-client not installed (or too old). Install using: dnf install insights-client')
    sys.exit(3)
    

# Check if the system has registered to Satellite or cloud.redhat.com
if not os.path.isfile('/etc/insights-client/.registered'):
    print('Unknown: You need to register to Red Hat Insights by running: insights-client register')
    sys.exit(3)
        
try:
    os.system('insights-client --check-result')
except:
    print('Unknown: insights-client failed to check in. Run: insights-client --check-result for more information.')
    sys.exit(3)

try:
    os.system('insights-client --show-result >/tmp/insights-result')
except:
    print('Unknown: insights-client failed to get results. Run: insights-client --show-results for more information.')
    sys.exit(3)

# Open the existing json file for loading into a variable
with open('/tmp/insights-result') as f:
    datastore = json.load(f)

# Count how many hit we have in total
total_issues = 0
for rule in datastore:
    total_issues += 1

# Count how many of those are security issues
security_issues = 0
for item in datastore:
   if item['rule']['category']['name'] == "Security":
      security_issues += 1

# Count how many of those are performance issues
performance_issues = 0
for item in datastore:
    if item['rule']['category']['name'] == "Performance":
        performance_issues += 1

# Count how many of those are stability issues
stability_issues = 0
for item in datastore:
    if item['rule']['category']['name'] == "Stability":
        stability_issues += 1

# Count how many of those are availability issues
availability_issues = 0
for item in datastore:
    if item['rule']['category']['name'] == "Availability":
        availability_issues += 1

print('Total issues:',total_issues,'.','Security issues:', security_issues,'. Availability issues:', availability_issues, '. Stability issues:', stability_issues, '. Performance issues:', performance_issues)
