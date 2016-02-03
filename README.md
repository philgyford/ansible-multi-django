# My first Ansible playbook

Very in progress.

## Vagrant

To set up the Vagrant box:

	$ vagrant up

To subsequently run ansible over the box again:

	$ vagrant provision

Or, possibly quicker:

	$ ansible-playbook --private-key=.vagrant/machines/default/virtualbox/private_key --user=vagrant --connection=ssh --inventory-file=.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory vagrant.yml

When recreating the box I did get an error at this point, and doing this fixed it:

	$ ssh-keygen -R [127.0.0.1]:2222

Once it's run you can ssh in to Vagrant using the `deploy` user (using the IP address set in `Vagrantfile` and `inventories/vagrant.ini`):

	$ ssh deploy@192.168.33.15

or as the standard `vagrant` user:

	$ vagrant ssh


## DigitalOcean

1. Have an SSH key set on your account: https://www.digitalocean.com/community/tutorials/how-to-use-ssh-keys-with-digitalocean-droplets

2. Create a new Ubuntu 14.04 x64 droplet, clicking the checkbox to add your SSH key (or add a new one).

3. You should be able to do (in this and subsequent examples, change the IP address to yours of course):

	```
	$ ssh root@188.166.146.145
	```

	If you get a warning about 'REMOTE HOST IDENTIFICATION HAS CHANGED!' after destroying and creating a new droplet, you can remove the warning with:

	```
	$ ssh-keygen -R 188.166.146.145
	```

4. Put the droplet's IP address in `inventories/production.ini`. eg:

	```
	[webservers]
	188.166.146.145
	```

5. Run the playbook (note, this first time we specify the user as `root`):

	```
	$ ansible-playbook --i inventories/production.ini -u root production.yml
	```

6. It should be all done. If the variable `ubuntu_use_firewall` is true (set in `env_vars/*.yml`), then you'll only be able to SSH to the `ubuntu_ssh_port` as the `ubuntu_deploy_user` eg, if the user is `deploy` and `ubuntu_ssh_port` is `1025`:

	```
	$ ssh deploy@188.166.146.145 -p 1025
	```

	These should fail (although the first will work if `ubuntu_ssh_port` is `22`, the default):

	```
	$ ssh deploy@188.166.146.145
	$ ssh root@188.166.146.145 -p 1025
	```

7. If the SSH port has now changed (as in the previous step), you'll need to add it to `inventories/production.ini`. eg:

	```
	[webservers]
	188.166.146.145:1025
	```

8. For subsequent runs, you'll need to set it to use the `ubuntu_deploy_user` and use `-s` to become sudo, and `-K` to be prompted for the sudo password (set in an `env_vars/*.yml` file):

	```
	$ ansible-playbook --i inventories/production.ini -u deploy -s -K production.yml
	```


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

* Clone apps' repos
* Install apps' pip requirements
* Create apps' databases
* How to set apps' environment variables?
* Copy databse with scp?
* Restore database?
* If django: Transfer media files from local machine?
* If django: Collect static files.
* Nginx and gunicorn
* Install memcached-dev and memcached if needed
* Git ssh stuff for updates
* Set up postgres backups to s3?


## TODO LATER

* Change test passwords in `env_vars/base.yml`.

* Fix the warning/failture if trying to do `$ ssh deploy@192.168.33.15` with Vagrant.

* Improve firewall stuff for Vagrant. At the moment it's just 'off'. Would be good to have it more similar to live, but I got confused over configuring SSH.


