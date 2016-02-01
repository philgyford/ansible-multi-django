# My first Ansible playbook

Very in progress.

## Vagrant

To set up the Vagrant box:

	$ vagrant up

To subsequently run ansible over the box again:

	$ vagrant provision

Or, possibly quicker:

	$ ansible-playbook --private-key=.vagrant/machines/default/virtualbox/private_key --user=vagrant --connection=ssh --inventory-file=.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory -v vagrant.yml

NOT WORKING: Once it's run you can ssh in to Vagrant using the `deploy` user:

	$ ssh deploy@192.168.33.15

And the password defined in `env_vars/base.yml`. The IP address is set in `Vagrantfile` and `inventories/vagrant`.


## DigitalOcean

1. Have an SSH key set on your account: https://www.digitalocean.com/community/tutorials/how-to-use-ssh-keys-with-digitalocean-droplets

2. Create a new Ubuntu 14.04 x64 droplet, clicking the checkbox for your SSH key (or add a new one).

3. You should be able to do (using your new IP address of course):

	$ ssh root@SERVER_IP_ADDRESS

4. Put the droplet's IP address in `inventories/production`.

5. Do:

	$ ansible-playbook --inventory-file=inventories/production -v production.yml


If you get a warning about 'REMOTE HOST IDENTIFICATION HAS CHANGED!' after destroying and creating a new droplet, you can remove the warning with:

	$ ssh-keygen -R SERVER_IP_ADDRESS





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

* Get server so far running on DigitalOcean.
* For DO, change/add `PermitRootLogin without-password` in `/etc/ssh/sshd_config` and restart sshd process.
* Install memcached-dev and memcached if needed
* Clone apps' repos
* Install apps' pip requirements
* Create apps' databases
* How to set apps' environment variables?
* Copy databse with scp?
* Restore database?
* If django: Transfer media files from local machine?
* If django: Collect static files.
* Nginx and gunicorn
* Git ssh stuff for updates
* Set up postgres backups to s3?


## TODO LATER

* Change test passwords in `env_vars/base.yml`.

* Fix the warning/failture if trying to do `$ ssh deploy@192.168.33.15` with Vagrant.

* Improve firewall stuff for Vagrant. At the moment it's just 'off'. Would be good to have it more similar to live, but I got confused over configuring SSH.


