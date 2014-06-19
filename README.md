# Hobo Fast Start for Heroku

- rvm
- ruby 2.1
- hobo 2.1
- rails 4.0
- using postgresql
- heroku tools
- Testing on Mac OS X (10.9.3) and Nitrous (chromebook)

Script to run the parts, and push it to staging, with a production server configured, using randomly named servers.

Assumes you want users to activate with email - so sets up MailGun (TODO: needs the API Key to be sorted).

Assumes that if you're using Mac OS X you're using railsinstaller or similar (just make your life easy, dammit).

Assumes that you have Mac OS X Postgresapp installed and running (no DB, no joy. For reals.)

## Why?

I deploy quite a bit on heroku when testing and thinking. I wanted a fast way to set up everything that I use for a Heroku-based deployment of the latest iteration of the fastest opinionated-but-override-capable app builder that I know - Hobo. IOW, this is a convention that I don't have to configure. After setting up three projects in a week, and re-starting them as I understood the problems better, I reckoned that I needed to speed up the process and not forget little tips and tricks. Like remembering to add 'protected\_attributes' gem.

## No. Why Ruby 2.1, Hobo 2.1 and Rails 4.0

Oh. I got gem conflicts that I couldn't be bothered to sort out when I used Rails 4.1. I'll look at this later. I wasn't that keen to use the features of Rails 4.1. I still forget about the new stuff in Rails 4.0. It'll happen. Eventually. Probably. Perhaps.

But I did want the most recent stable Ruby and the most recent stable Hobo. Just couldn't trivially get the most recent Rails, too. 'k?

# How To Use It

Fork/clone this repo. Run the script with the name of a new project, and you'll get a newly built directory with a staging and a production heroku server (default push is to staging), configured for bitbucket (my preferred Git repo), and the basic app pushed to staging, with the db:migration done for the core Users model.

You'll have a branch - 'staging'. When you develop, commit changes to staging and push to heroku from there. When you're ready, merge staging into master, and push from there to the live production server. Simples.

$ ./gen-my-project {name}

This script will:

- grab/update rvm
- install/update MRI ruby
- create a project gemset
- install gems needed to run hobo
- prepare database user for a project
- generate a hobo app using postgresql
- update heroku toolbelt
- create a heroku live server and a staging server, with addons for Heroku Postgres and MailGun for email activation
- configure project git to push to a bitbucket project
- configure git to push to heroku servers off the branches 'master' and 'staging', default is staging
- TODO: put the ruby and gemset declarations in the project Gemfile
- TODO: store default Hobo admin credentials or use them for future projects, and set them up in the DB seed
- TODO: store MailGun API Key for this project out of the project tree
- TODO: give you core hobo feature tests (basic user admin tests with cucumber)
- TODO: run your initial cucumber tests
- push the current iteration to staging
- TODO: create some aliases so that standard sequences of hobo activity get done (closest approach to continuous deployment)

In other words, once you've run this, you're ready to rip on adding models, tweaking access control and views, and it can be made visible in two steps - stage and live, with a basic BDD env in place. 

And, with the exception of getting stuff ready to use, you can abandon the rvm installation used to create the environment, or use a different repo hosting service (erm, GitHub?)

# Aftercare

- 'git checkout staging'
- do the work, with branches off staging if needed
- merge changes to staging
- 'git push heroku' will push the staging branch to the staging server for testing/demo
- switch to the master branch when happy, and merge your staging branch, the 'git push heroku' will push to the live server

There's some other bits that I constantly forget. I'll be poking around automating those.

'hobo g migration' - run this all the time

'rake db:migrate' - and remember to do this on the servers; some simple deploy script. Not Puppet - too much overhead for this type of project?
