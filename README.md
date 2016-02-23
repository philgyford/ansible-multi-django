# My first Ansible playbook

Very in progress.

Designed to host multiple websites, from different git repositories, on a single webserver. Can be used with a Vagrant virtual machine and a DigitalOcean droplet (not tested with anything else).


## Apps

You'll need to alter `roles/apps/vars/main.yml` to reflect the websites (called "apps" here you want to install). Each item in the list has one or more of these elements:

* `name`: Required. No spaces. Will be used as a directory name for where its git repo will be checked out to. A single directory name that will be put within `apps_path` (defined in an `env_vars/*.yml` file). Also used for a virtualenv name, if required.

* `git_repo`: Optional. The `https://github.com...` path to the git repository. It won't work with a `git@github.com...` path. Although optional, not much will happen without this.

* `git_repo_branch`: Optional. The name of the branch to check out. If omitted, defaults to `'master'`.

* `python_version`: Optional. e.g. `3.5.1`. If set, will be used to create a python virtualenv for this app using pyenv.

* `pip_requirements_file`: Optional. If the app has a pip requirements file, set the path to it within the repo here. eg, `requirements.txt`. Otherwise, omit this. If set, the python packages will be installed.

* `db_type`: Optional. Currently must be 'postgresql' if present.

* `db_password`: Optional. Password for the database. Database name and username will be the same as the app's `name`.

* `django_settings_file`: Optional. Python path to the settings file within the app, eg, if the app is in `django-myproject/myproject/settings/live.py` then use `myproject.settings.live`.

* `environment_variables`: Optional. A dictionary of keys/values that will be added to the virtualenv's `postactivate` script.

* `nginx_config`: Optional. If present, the site will have its Nginx site enabled.

    Variables within `nginx_config`:
    * `allowed_hosts`: Required. A dictionary of domain patterns for environment names, eg:
            allowed_hosts:
              production: 'mydomain.com|www.mydomain.com'
              vagrant: 'mydomain.dev|www.mydomain.dev'

If you want a custom Nginx config file, copy `roles/apps/templates/nginx_site_config_default.j2` to `roles/apps/templates/nginx_site_config_{{ app.name }}.j2` and customise that. NOTE: Not currently working, see 'TODO LATER'.

In addition, the `roles/apps/vars/vault.yml` file is encrypted with ansible-vault, and contains variables that can be used in `roles/apps/vars/main.yml`. eg, in `main.yml` we might have:

    apps:
	  - name: 'pepysdiary'
	    db_password: '{{ pepysdiary_db_password }}'

And in `vault.yml` we'd have this (except the entire file is encrypted of course):

	pepysdiary_db_password: 'secretpassword'

### Django sites

We assume this structure for Django sites, eg:

```
myproject
├── manage.py
├── myproject/
│   ├── media/
│   ├── static_collected/
│   ├── settings/
│   ├── templates/
│   └── wsgi.py
└── requirements.txt
```

(`myproject` is the same as the `name` variable in the `apps` config, above.)


## Vagrant

To set up the Vagrant box:

	$ vagrant up

To subsequently run ansible over the box again:

	$ vagrant provision

Or, possibly quicker:

	$ ansible-playbook --private-key=.vagrant/machines/default/virtualbox/private_key --user=vagrant --connection=ssh --inventory-file=.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory --ask-vault-pass vagrant.yml

When recreating the box I did get an error at this point, and doing this fixed it:

	$ ssh-keygen -R [127.0.0.1]:2222

Once it's run you can ssh in to Vagrant using the `deploy` user (using the IP address set in `Vagrantfile` and `inventories/vagrant.ini`):

	$ ssh deploy@192.168.33.15

or as the standard `vagrant` user:

	$ vagrant ssh


## DigitalOcean

1. Have an SSH key set on your account: https://www.digitalocean.com/community/tutorials/how-to-use-ssh-keys-with-digitalocean-droplets

2. Create a new Ubuntu 14.04 x64 droplet, clicking the checkbox to add your SSH key (or add a new one).

3. You should be able to do (in this and subsequent examples, change the IP address to your droplet's of course):

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
	$ ansible-playbook --inventory-file=inventories/production.ini --user=root --ask-vault-pass production.yml
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

8. For subsequent runs, you'll need to set it to use the `ubuntu_deploy_user` and use `--sudo` to become sudo, and `--ask-sudo-pass` to be prompted for the sudo password (set in an `env_vars/*.yml` file):

	```
	$ ansible-playbook --inventory-file=inventories/production.ini --user=deploy --sudo --ask-sudo-pass production.yml
	```


## TODO

* Set allowed hosts and django settings file per env+app combo in environment_variables and nginx config.
* Nginx and gunicorn
* Use a `runtime.txt` file for python version.
* Install memcached-dev and memcached if needed
* Copy databse with scp?
* Restore database?
* If django: Transfer media files from local machine?
* Git ssh stuff for updates
* Set up postgres backups to s3?
* Add maintenance_on.html page? (in nginx config)


## TODO LATER

* In `roles/apps/tasks/set_up_nginx.yml` we should replace the `src=nginx_site_config_default.j2` with `src={{ lookup('first_found', ['nginx_site_config_{{ item.name }}.j2', 'nginx_site_config_default.j2']) }}` to allow for using a config per app. It was recently fixed <https://github.com/ansible/ansible/issues/14190> but isn't in v2.0.0.2. Remove NOTE in instructions above.

* We're currently only setting up virtualenvs if it's a python app. But do we also need them for webserver and environment variables if its PHP for example?

* Make Vagrant more similar to live. Maybe http://hakunin.com/six-ansible-practices ?

* Improve firewall stuff for Vagrant. At the moment it's just 'off'. Would be good to have it more similar to live, but I got confused over configuring SSH.

* Rename pepysdiary `live.py` settings file? Hard-code the django apps' settings file name based on which env we're in?
