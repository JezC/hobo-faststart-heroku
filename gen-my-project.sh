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

# heroku toolbelt update - get it over sooner rather than failing later
# TODO: Linux distros probably need apt-get or other stuff
heroku update

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
curl -k -X POST --user "${bitbucket_user}:${bitbucket_password}" "https://api.bitbucket.org/1.0/repositories" -d "name=${PROJECT_NAME}"

git remote add origin git@bitbucket.org:${bitbucket_user}/${PROJECT_NAME}
git push origin master

git config push.default tracking

# Create staging branch and use it
git checkout -b staging

git branch -u staging/master staging

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
web: bundle exec unicorn -c config/unicorn.rb -p \${PORT}
HERE

# Add unicorn to the gemset and configure it
cat >> Gemfile << HERE

gem 'unicorn'

group :development do
	# if ruby > 2.0
	gem 'jazz_hands'
	gem 'better_errors', :require => false
	gem 'binding_of_caller', :require => false
	gem 'meta_request', :require => false
	gem 'awesome_print', :require => false
	gem 'quiet_assets', :require => false
	gem 'bullet', :require => false
	gem 'flay', :require => false
	gem 'rails_best_practices', :require => false
	gem 'reek', :require => false
	gem 'brakeman', :require => false
end

# rspec is in development and test so that developer tools can run without RAILS_ENV=test
group :development, :test do
  gem 'rspec-rails', '~> 2.0'
  # if ruby > 2.0, use pry
  gem 'pry-rails'
  gem 'pry-byebug'
  # else
  # gem 'debugger', :require => false
end

group :test do
	gem 'cucumber-rails', :require => false
	gem 'shoulda-matchers', :require => false
	gem 'factory_girl_rails', :require => false
	gem 'database_cleaner', :require => false
	gem 'selenium-webdriver', :require => false
end

group :production do
	gem 'rails_12factor'
end
HERE

if ! bundle install
then
	echo "Like. No. The dev and test gems are broked."
	exit 1
fi

rails g rspec:install
rails g cucumber:install

# add unicorn configuration - Heroku default
cat > config/unicorn.rb << HERE
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

bundle install

git config --global push.default simple
git config heroku.remote staging
git config push.default tracking
git add Procfile config/unicorn.rb Gemfile
git commit -am "Heroku config"
git checkout -b staging --track staging/master

if ! heroku apps:create --region=${HEROKU_REGION} --addons heroku-postgresql,mailgun --remote staging
	then
	echo "Failed to create Heroku staging server with addons"
	exit 1
fi

# Somewhat hinky method to extract the randomly generated asset name at Heroku
TEMPFILE=`mktemp heroku-XXXX.tmp`

heroku info -s > ${TEMPFILE}
`grep "^domain_name=" ${TEMPFILE}`
stage_name="${domain_name}"

rm ${TEMPFILE}

# Set up email

cat > config/initializers/email.rb << HERE
ActionMailer::Base.smtp_settings = {
  :port           => ENV['MAILGUN_SMTP_PORT'],
  :address        => ENV['MAILGUN_SMTP_SERVER'],
  :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
  :password       => ENV['MAILGUN_SMTP_PASSWORD'],
  :domain         => '${domain_name}',
  :authentication => :plain,
}
ActionMailer::Base.delivery_method = :smtp
HERE

# Set up default administrator
# If you have environment parameters for hfs_username, hfs_email_address and hfs_password, you'll get a default administrator set up and ready hen you use "rake db:setup" or "rake db:seed"
cat >> db/seeds.rb << HERE

if ENV['hfs_username'] 
  administrator = User.create!(
    [
      {
        :name => ENV['hfs_username'], 
        :email_address => ENV['hfs_email_address'], 
        :administrator => true, 
        :password => ENV['hfs_password'], 
        :password_confirmation => ENV['hfs_password']
      } 
    ], 
    :without_protection => true
  )
else
  Rails.logger.debug { "Set environment variables hfs_username, hfs_email_address, hfs_password for default administrator" }
end
HERE

# make sure the bundle of gems works

if ! bundle install
then
	echo "Final bundle install failed. Like, really. Urgh."
	exit 1
fi

# generate the bits and bobs needed for a deployment
rake assets:precompile

# git add Gemfile Procfile config/unicorn.rb config/initializers/email.rb
# Meh. 'git add .' adds everything. And we've autogenerated so far. 
git add .
git commit -am "Configured for heroku"

git branch --set-upstream staging staging/master

# this should push the staging branch to the staging server as the master branch on heroku

if ! git push staging
	then
	echo "Failed to push to the staging server; need to set up heroku production server"
	exit 1
fi

heroku run rake db:setup --app ${stage_name}

## TODO: Really should push the Twitter/Facebook API Key and Secret. But we don't have them here... 
## And I'm not happy keeping them in a project git. They should be in the environment, but that means
## setting up some store for them, locally. Maybe, someday, I'll conditioanlly set these up. In the interim...
## at the end of the script we tell people to get the keys and secrets and to configure them.

git checkout master
git merge staging

# TODO: Make this work... properly
# git checkout -b staging --track staging/master

if ! git push 
	then
	echo "Failed to push to the shared repo - bailing out; must set up heroku production server"
	exit 1
fi

if ! heroku apps:create --region=${HEROKU_REGION} --addons heroku-postgresql,mailgun --remote production
	then
	echo "Failed to create Heroku production server with addons"
	exit 1
fi

if ! heroku run rake db:migrate --remote production
then
	echo "I dunno. Something failed running the rake. Need to sort that and get the databse working."
	exit 1
fi

echo "Should be all ready. Now get Twitter & Facebook keys and secrets and use heroku config:set TWITTER_KEY={TWITTER_KEY} to set them up"
