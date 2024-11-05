#!/usr/bin/python3
# sudo@redhat.com, 2020
# US Presidental election data tool, spits out useful info regarding the presidental vote in a specific state

# Import required modules
import sys
import os
import argparse
import math
from datetime import datetime

# Argument parsing and --help
parser = argparse.ArgumentParser(usage='%(prog)s [options]')
parser.add_argument('--Harris', metavar='N', type=int, default=0, help='Number of votes for Harris')
parser.add_argument('--trump', metavar='N', type=int, default=0, help='Number of votes for Trump')
parser.add_argument('--reported', metavar='N', type=int, default=0, help='Total votes reported')
parser.add_argument('--percent', metavar='N', type=float, default=0, help='Percent votes reported')
parser.add_argument('--roundup', metavar='true|false', default='true', help='Round down to zero')
args = parser.parse_args()

Harris = args.Harris
trump = args.trump
roundup = args.roundup
reported = args.reported
percent = args.percent
vote_per_percent = (reported / percent)
total_votes = vote_per_percent * 100
votes_left = total_votes - reported

dateTimeObj = datetime.now()
print("Running analysis: ", dateTimeObj)

# Yes, below is a simplification, as we are not considering that remaining 
# votes may be cast on other candidates than Harris or Trump. Doing so introduces a moving target which takes us to
# a realm of math I do not master. Feel free to fix if you math skills are better than mine :-)

Harris_trump = Harris + trump
other = reported - Harris_trump
nother = (total_votes - other) / 2

# trump needs
trump_needs = nother - trump + 1
trump_needs_per = (trump_needs / votes_left)*100

# Harris needs
Harris_needs = nother - Harris + 1
Harris_needs_per = (Harris_needs / votes_left)*100

print("Harris votes: ", Harris)
print("Trump votes: ", trump)
print("Total votes in: ", reported)
if ( roundup == "true" ):
    print("Votes per percent: ", int(vote_per_percent))
else:
    print("Votes per percent: ", vote_per_percent)

if ( roundup == "true" ):
    print("Total votes: ", int(total_votes))
else:
    print("Total votes: ", total_votes)

if ( roundup == "true" ):
    print("Votes left to report: ", int(votes_left))
else:
    print("Votes left to report: ", votes_left)

if ( Harris > trump ):
    diff = Harris - trump
    print("Harris leads with ", diff, "votes")
    if ( roundup == "true" ):
        print("Trump needs number of votes: ", int(trump_needs))
    else:
        print("Trump needs number of votes: ", trump_needs)
    print("Trump needs % of vote left: ", trump_needs_per)
    if ( votes_left > diff ):
        print("Trump can still win.")
    else:
        print("Harris won the state.")

if ( trump > Harris ):
    diff = trump - Harris
    print("Trump leads with ", diff, "votes")
    if ( roundup == "true" ):
        print("Harris needs number of votes: ", int(Harris_needs))
    else:
        print("Harris needs number of votes: ", Harris_needs)
    print("Harris needs % of vote left: ", Harris_needs_per)
    if ( votes_left > diff ):
        print("Harris can still win.")
    else:
        print("Trump won the state.")
