Service Stash
=============

Regularly backup a cloud foundry service to a cloud storage provider of your choice.

1. Clone this application

  ``git clone git@github.com:danhigham/service_stash.git``

2. Copy the example config to config.yml

  ``
  cd service_stash && 
  cp config.yml.example config.yml
  ``

3. Tailor the config to suit your requirements

4. Bundle install and deploy the application, using the handy script

  ``
  bundle install &&
  ./deploy.rb
  ``


