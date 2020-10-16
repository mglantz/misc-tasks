# Name: check_insight.py
#
# Description: Print out summary of detected issues received from Red Hat Insight
# Prereq: latest version of Red Hat Insight installed on the system and system registered to Satelite or cloud.redhat.com.
#
# Author: Magnus Glantz, sudo@redhat.com, 2020

# Import required modules
import sys 
import os
import subprocess
try:
    import simplejson as json
except ImportError:
    import json
import rpm
import argparse

# We need to discard some info to /dev/null later on
DEVNULL = open(os.devnull, 'wb')

# Argument parsing and --help
parser = argparse.ArgumentParser(usage='%(prog)s [options]')
parser.add_argument('--mon', metavar='true|false', default='false', help='Activating monitoring mode enables all below options - otherwise ignored. Default: false')
parser.add_argument('--wtotal', metavar='0-999', type=int, default=4, help='Sets warning level for total nr of accumulated issues. Default: 4')
parser.add_argument('--ctotal', metavar='0-999', type=int, default=12, help='Sets critical level for total nr of accumulated issues. Default: 12')
parser.add_argument('--wall', metavar='0-999', type=int, default=0, help='Overrides all below. Sets same warning level for all types (but not total), nr of issues. Default: 0')
parser.add_argument('--call', metavar='0-999', type=int, default=0, help='Overrides all below. Sets same critical level for all types (but not total), nr of issues. Default: 0')
parser.add_argument('--wstab', metavar='0-999', type=int, default=1, help='Sets warning level for stability issues, nr of issues. Default: 1')
parser.add_argument('--cstab', metavar='0-999', type=int, default=3, help='Sets critical level for stability issues, nr of issues. Default: 3')
parser.add_argument('--wavail', metavar='0-999', type=int, default=1, help='Sets warning level for availability issues, nr of issues. Default: 1')
parser.add_argument('--cavail', metavar='0-999', type=int, default=3, help='Sets critical level for availability issues, nr of issues. Default: 3')
parser.add_argument('--wsec', metavar='0-999', type=int, default=1, help='Sets warning level for security issues, nr of issues. Default: 1')
parser.add_argument('--csec', metavar='0-999', type=int, default=3, help='Sets critical level for security issues, nr of issues. Default: 3')
parser.add_argument('--wperf', metavar='0-999', type=int, default=1, help='Sets warning level for performance issues, nr of issues. Default: 1')
parser.add_argument('--cperf', metavar='0-999', type=int, default=3, help='Sets critical level for performance issues, nr of issues. Default: 3')
parser.add_argument('--wexit', metavar='0-999', type=int, default=1, help='Sets exit code for warning. Nagios compliant default: 1')
parser.add_argument('--cexit', metavar='0-999', type=int, default=2, help='Sets exit code for critical. Nagios compliant default: 2')
args = parser.parse_args()

# Passed arguments
mon = args.mon

# If we are in monitoring mode deal with all the rest of the parameters as well
if mon == "true":
    wstab = args.wstab
    cstab = args.cstab
    wavail = args.wavail
    cavail = args.cavail
    cperf = args.cperf
    wperf = args.wperf
    wsec = args.wsec
    csec = args.csec
    wexit = args.wexit
    cexit = args.cexit
    ctot = args.ctotal
    wtot = args.wtotal
    call = args.call
    wall = args.wall

# If --wall is set, set all warning levels to whatever was set
    if wall != 0:
        wstab = wall
        wavail = wall
        wsec = wall
        wperf = wall

# If --call is set, set all critical levels to whatever was set
    if call != 0:
        cstab = call
        cavail = call
        csec = call
        cperf = call

# Check for the insights-client package, if it's not installed, nothing below will work.
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

# Remove .lastupload identifier if it exists
if os.path.isfile('/etc/insights-client/.lastupload'):
    os.remove('/etc/insights-client/.lastupload')
        
try:
    subprocess.run(['insights-client'], check = True, stdout=DEVNULL, stderr=DEVNULL)
except subprocess.CalledProcessError:
    print('Unknown: insights-client failed to check in. Run: insights-client --check-result for more information.')
    sys.exit(3)

# Remove stdout file
if os.path.isfile('/tmp/insights-result'):
    os.remove('/tmp/insights-result')

try:
    os.system('insights-client --show-result >/tmp/insights-result')
    if not os.system('insights-client --show-result >/tmp/insight-result') == 0:
        raise Exception('insights-client command failed')
except:
    print('Unknown: insights-client failed to get results. Run: insights-client --show-results for more information.')
    sys.exit(3)

if not os.path.isfile('/etc/insights-client/.lastupload'):
    print('Unknown: insights-client failed to get result from cloud.redhat.com. Run: insights-client --show-results for more information.')
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

print('Total issues: ',total_issues,'. Security issues: ', security_issues,'. Availability issues: ', availability_issues, '. Stability issues: ', stability_issues, '. Performance issues: ', performance_issues, sep="")

# We are not in monitoring mode, so let's exit with 0
if mon == "false" or mon == "False":
    sys.exit(0)

# If monitoring mode has been activated, let's evaluate warning and critical levels and exit accordingly
if mon == "true" or mon == "True":
# If something has hit critical levels, we exit with critical exit code
    if total_issues >= ctot or security_issues >= csec or availability_issues >= cavail or stability_issues >= cstab or performance_issues >= cperf:
        sys.exit(cexit)
# If something has hit warning levels, we exit with warning exit code
    elif total_issues >= wtot or security_issues >= wsec or availability_issues >= wavail or stability_issues >= wstab or performance_issues >= wperf:
        sys.exit(wexit)
# If we're here, all went OK and we exit with 0
    else:
        sys.exit(0)
