#!/bin/bash
# script to undo a failed a failed project generation
# - remove gemset
# - remove postgres database and user
# - remove heroku app(s)
# - remove bitbucket repository - ah, if only it was possible
# - remove project directory
# any one or more of these may not exist; we don't know how far through the project creation got
# the script uses a common, but not shared (DRY fail), set of environment parameters and initial actions

RC_FILE=~/.hobo_faststart.rc

if [ ! -f ${RC_FILE} ]
then
	echo "Must have a ~/.hobo_faststart.rc with 'bitbucket_name=username' and 'bitbucket_password=password'"
	exit 1
else
	source ${RC_FILE}
fi

# use RUBY_REVISION because rvm uses RUBY_VERSION, and we get usage conflicts. The peril of sourcing scripts.

RUBY_REVISION=2.1.2
HOBO_VERSION=2.1.0
RAILS_VERSION=4.0.5
HEROKU_REGION=eu

# Get a project name, or die on fail

if [ $# -ne 1 ]
	then
	echo "$0 needs a project name!
	$0 project"
	exit 1
else
	if [ $1 = "-?" -o $1 = "-h" -o $1 = "--help" ]
		then
		echo "You're beyond help. Use the source, Luke."
		exit 1
	else 
		PROJECT_NAME=$1
	fi
fi

# if there is no RVM, get it. If there is, update it
if which rvm 2>&1 > /dev/null
	then rvm get stable
else
	\curl -sSL https://get.rvm.io | bash -s stable
fi

# heroku toolbelt update - get it over sooner rather than failing later
# TODO: Linux distros probably need apt-get or other stuff
heroku update

# we want rvm to run as the function - so we can switch rubies, gemsets, etc.

source "$HOME/.rvm/scripts/rvm"

###### End of section shared with gen-my-project

# get bitbucket ID, remove it
if [ -d "${PROJECT_NAME}" ]
then
	cd ${PROJECT_NAME}
	bitbucket_id=$(git remote -v | grep "^origin.*fetch" | sed -e 's/^origin //' -e 's/ (fetch)//')
	cd ..
fi

# get heroku staging app ID, remove it
if [ -d "${PROJECT_NAME}" ]
then
	cd "${PROJECT_NAME}"
	heroku_staging_id=$(git remote -v | grep "^staging.*fetch" | sed -e 's/^staging.git@heroku.com://' -e 's/.git (fetch)//')
	if [ -n "${heroku_staging_id}" ]
	then
		heroku apps:destroy --app ${heroku_staging_id} --confirm ${heroku_staging_id}
	fi
	heroku_production_id=$(git remote -v | grep "^production.*fetch" | sed -e 's/^production.git@heroku.com://' -e 's/.git (fetch)//')
	if [ -n "${heroku_production_id}" ]
	then
		heroku apps:destroy --app ${heroku_production_id} --confirm ${heroku_production_id}
	fi
	cd ..
fi

# get database ID and remove tables, remove user
# drop tables
dropdb "${PROJECT_NAME}_development"
dropdb "${PROJECT_NAME}_test"
dropdb "${PROJECT_NAME}"
# drop user
dropuser "${PROJECT_NAME}"

# remove project gemset
rvm gemset delete ${PROJECT_NAME}

# remove project directory
# rm -rf ${PROJECT_NAME}
