#!/usr/bin/env python3
#
# This script deletes all branches from a git repository
# which are not in the Mercurial repository given as the parameter.
#
# cd into the git repo and invoke <script> <path-to-the-hg-repo>

import sys
from subprocess import *

##### GET OPEN BRANCHES #####

HG_REPO = sys.argv[1]

p = Popen(['hg', 'branches'], stdout=PIPE, cwd=HG_REPO)
out = p.communicate()[0]

if p.returncode != 0:
	print("'hg branches' returned non-zero exit status, exiting", file=sys.stderr)
	sys.exit(1)

open_branches = set()

for line in out.decode('utf-8').split('\n'):
	try:
		branch = line.split()[0]
		print('Adding {0} to the set of open branches'.format(branch))
		open_branches.add(branch)
	except IndexError:
		pass

##### GET CLOSED BRANCHES #####

p = Popen(['git', 'branch'], stdout=PIPE)
out = p.communicate()[0]

if p.returncode != 0:
	print("'git branch' returned non-zero exit status, exiting", file=sys.stderr)
	sys.exit(1)

branches = set()

for line in out.decode('utf-8').split('\n'):
	try:
		branch = line.strip()
		if branch[0] == '*':
			branch = branch[2:]
		if branch == 'master':
			continue
		branches.add(branch)
	except IndexError:
		pass

closed_branches = branches - open_branches

##### DELETE CLOSED BRANCHES #####

for branch in closed_branches:
	check_call(['git', 'branch', '-D', branch])

##### INVOKE THE GARBAGE COLLECTOR #####

print('Invoking the garbage collector...')
check_call(['git', 'gc', '--aggressive'])
