# My first Ansible playbook

Very in progress.

	$ vagrant provision

Once it's run you can ssh in to Vagrant using the `deploy` user:

	$ ssh deploy@192.168.33.15

And the password defined in `env_vars/base.yml`. The IP address is set in `Vagrantfile`.

## Notes

`roles/common/` is stuff to do with setting up the basic server, before we
get to webservers, databases, etc.


## TODO

* Change test passwords in `env_vars/base.yml`.

* Fix the warning/failture if trying to do `$ ssh deploy@192.168.33.15` with Vagrant.

* Improve firewall stuff for Vagrant. At the moment it's just 'off'. Would be good to have it more similar to live, but I got confused over configuring SSH.


