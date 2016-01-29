# My first Ansible playbook

Very in progress.

	$ vagrant provision

Once it's run you can ssh in to Vagrant using the `deploy` user:

	$ ssh deploy@192.168.33.15

And the password defined in `env_vars/base.yml`. The IP address is set in `Vagrantfile`.

## Notes

`roles/common/` is stuff to do with setting up the basic server, before we
get to webservers, databases, etc.

Each "app" (eg, a website) should have its variables set in the `apps` list in `roles/apps/vars/main.yml`. eg:

	apps:
	  - repo: git@github.com:philgyford/twelescreen.git
	    virtualenv: twelescreen
	  - repo: git@github.com:philgyford/myphpapp.git

If the app requires a python virtualenv, set its `virtualenv` name. Otherwise, leave that property out.

## TODO

* Install memcached-dev and memcached if needed
* Clone apps' repos
* Install apps' pip requirements
* Create apps' databases
* How to set apps' environment variables?
* Copy databse with scp?
* Restore databse?
* If django: Transfer media files from local machine?
* If django: Collect static files.
* Nginx and gunicorn
* Git ssh stuff for updates
* Set up postgres backups to s3?


## TODO LATER

* Change test passwords in `env_vars/base.yml`.

* Fix the warning/failture if trying to do `$ ssh deploy@192.168.33.15` with Vagrant.

* Improve firewall stuff for Vagrant. At the moment it's just 'off'. Would be good to have it more similar to live, but I got confused over configuring SSH.


