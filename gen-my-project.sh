#!/bin/bash

# script to generate a Hobo project, with heroku deployment using Postgresql
# Assumes:
# Postgres is installed, running and on the PATH
# You have a network connection.
# You have a heroku account and the heroku tools on the PATH
# You have a BitBucket account with username and password stored in a file in your home directory
# You know that a European service on Heroku is not Safe Harbour compliant - data can be passed to the US

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

# we want rvm to run as the function - so we can switch rubies, gemsets, etc.

source "$HOME/.rvm/scripts/rvm"

# install ruby 2.1
if ! rvm install ${RUBY_REVISION}
	then 
	echo "Problem installing Ruby."
	exit 1
fi

rvm use ruby-${RUBY_REVISION}

# create the projects' gemset, and switch to the Ruby & Gemset

rvm gemset create ${PROJECT_NAME}

rvm use ruby-${RUBY_REVISION}@${PROJECT_NAME}

echo ruby-${RUBY_REVISION} > .ruby-version
echo ${PROJECT_NAME} > .ruby-gemset

# generate the Gem file:

cat > Gemfile << HERE
source 'https://rubygems.org'

ruby '${RUBY_REVISION}'

#ruby-gemset='${PROJECT_NAME}'

gem 'rails', '${RAILS_VERSION}'

gem 'hobo', '${HOBO_VERSION}'

gem 'pg'

gem 'attr_protected'

gem 'unicorn'

gem 'protected_attributes'
HERE

if ! bundle install
	then
	echo "Failed to set up gems properly"
	exit 1
fi

# Set up Postgresql
if ! createuser -d ${PROJECT_NAME}
	then 
	echo "Postgresql user creation failed"
	exit 1
fi

# Create the hobo project
if ! hobo new ${PROJECT_NAME} -d postgresql
	then 
	echo "Hobo generation failed."
	exit 1
fi

# Now we start work on the Heroku parts

cd ${PROJECT_NAME}

if [ ! -d .git ]
then
	echo "Hobo Wizard must generate initial git - and failed to do so for some reason"
	exit 1
fi

# Must set up Git Repo before the heroku app is created
curl -k -X POST --user "${bitbucket_user}:${bitbucket_password}" https://api.bitbucket.org/1.0/repositories -d ${PROJECT_NAME}

git remote add origin git@bitbucket.org:${bitbucket_user}/${PROJECT_NAME}

echo "### Updating Heroku"
if apt-get -v 2>&1 > /dev/null
then
  apt-get install heroku-toolbelt
else
  heroku update
fi

echo "### Adding heroku features"
# Add Procfile

cat > Procfile << HERE
web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
HERE

# Add unicorn to the gemset and configure it
cat >> Gemfile << HERE

gem 'unicorn'
HERE

cat >> config/unicorn.rb << HERE
worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
timeout 15
preload_app true

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
HERE

# add rails_12factor
cat >> Gemfile << HERE

gem 'rails_12factor'
HERE

if ! heroku apps:create --region=${HEROKU_REGION} --addons heroku-postgresql,mailgun --remote staging
	then
	echo "Failed to create Heroku staging server with addons"
	exit 1
fi

if ! git push 
	then
	echo "Failed to push to the shared repo - bailing out; must set up heroku production server"
fi

git config heroku.remote staging
git config push.default tracking
git checkout -b staging --track staging/master

if ! git push heroku
	then
	echo "Failed to push to the staging server; need to set up heroku production server"
fi

if ! heroku run rake db:migrate
then
	echo "I dunno. Something failed running the rake. Need to sort that and get the "
	exit 1
fi

if ! heroku apps:create --region=${HEROKU_REGION} --addons heroku-postgresql,mailgun --remote production
	then
	echo "Failed to create Heroku production server with addons"
	exit 1
fi

git branch --set-upstream master production/master
