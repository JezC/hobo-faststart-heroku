# Hobo Fast Start for Heroku

rvm
ruby 2.1
hobo 2.1
rails 4.1
using postgresql
heroku tools
Tested on Mac OS X (10.9.3) and Nitrous (chromebook)

Script to run the parts, and push it to staging.

Assumes you want users to activate with email - so sets up MailGun (needs the API Key).

Assumes that if you're using Mac OS X you're using railsinstaller or similar (just make your life easy, dammit)

Assumes that you have Mac OS X Postgresapp installed and running (no DB, no joy. For reals.)

## Why?

I deploy quite a bit on heroku when testing and thinking. I wanted a fast way to set up everything that I use for a Heroku-based deployment of the latest iteration of the fastest opinionated-but-override-capable app builder that I know - Hobo. IOW, this is a convention that I don't have to configure. After sttting up three projects in a week, and re-starting them as I understood te problems better, I reckoned that I needed to speed up the process and not foregt little tips and tricks.

# How To Use It

Fork/clone this repo and change directory. Run the script with the name of a new project, and you'll get a newly built directory ready to turn into a heroku project, configured for bitbucket (my preferred Git repo), with a heroku app named after the project, and the basic app pushed live.

$ ./gen-my-project {name}

This script will:

- grab rvm
- install/update MRI ruby
- create a project gemset
- install gems needed to run hobo
- check that you have a local postgresql
- prepare for a project database (production, development and test)
- generate a hobo app using postgresql
- put the ruby and gemset declarations in the project Gemfile
- store default Hobo admin credentials or use them for future projects, and set them up in the DB seed
- store MailGun API Key for this project out of the project tree
- create a heroku live server and a staging server, with addons for Heroku POstgres and MailGun for email activation
- configure git to push to heroku servers off the branches 'master' and 'staging'
- give you core hobo feature tests (basic user admin)
- set up and read from a home directory confguration the defaults that you want for your admin account and create the seed
- run your initial cucumber tests
- push it to staging
- create some aliases so that standard sequences of hobo activity get done (closest approach to continuous deployment)
- set up bitbucket repo and push to that

In other words, once you've run this, you're ready to rip on adding models, tweaking access control and views, and it can be made visible in two steps - stage and live, with a basic BDD env in place. 

And, with the exception of getting stuff ready to use, you can abandon the rvm installation used to create the environment. 