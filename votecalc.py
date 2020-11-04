#!/usr/bin/python3
# sudo@redhat.com, 2020
# US Presidental election data tool, spits out useful info regarding the presidental vote in a specific state

# Import required modules
import sys
import os
import argparse
import math

# Argument parsing and --help
parser = argparse.ArgumentParser(usage='%(prog)s [options]')
parser.add_argument('--biden', metavar='N', type=int, default=0, help='Number of votes for Biden')
parser.add_argument('--trump', metavar='N', type=int, default=0, help='Number of votes for Trump')
parser.add_argument('--reported', metavar='N', type=int, default=0, help='Total votes reported')
parser.add_argument('--percent', metavar='N', type=int, default=0, help='Percent votes reported')
args = parser.parse_args()

biden = args.biden
trump = args.trump
reported = args.reported
percent = args.percent
vote_per_percent = (reported / percent)
total_votes = vote_per_percent * 100
votes_left = total_votes - reported

print("Biden votes: ", biden)
print("Trump votes: ", trump)
print("Total votes in: ", reported)
print("Votes per percent: ", vote_per_percent)
print("Total votes: ", total_votes)
print("Votes left to report: ", votes_left)

if ( biden > trump ):
    diff = biden - trump
    print("Biden leads with ", diff, "votes")
    if ( votes_left > diff ):
        print("Trump can still win.")
    else:
        print("Biden won the state.")

if ( trump > biden ):
    diff = trump - biden
    print("Trump leads with ", diff, "votes")
    if ( votes_left > diff ):
        print("Biden can still win.")
    else:
        print("Trump won the state.")


