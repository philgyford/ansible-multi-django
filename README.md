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

    Within there should be one dictionary per environment (eg, `production`), each containing config variables:
    * `allowed_hosts`: Required. A dictionary of domain patterns for environment names.

* `gunicorn_config`: Optional. If present Gunicorn and Supervisor will be set up.

    Within there should be one dictionary per environment (eg, `production`), each containing config variables:
    * `max_requests`: Optional, default `1000`
    * `num_workers`: Optional, default `3`
    * `timeout_seconds`: Optional, default `30`

eg:

    nginx_config:
      production:
        allowed_hosts: 'mydomain.com|www.mydomain.com'
      vagrant:
        allowed_hosts: 'mydomain.dev|www.mydomain.dev'
    gunicorn_config:
      production:
        max_requests: 1000
        num_workers: 3
        timeout_seconds: 30
      vagrant:
        max_requests: 1

If you want a custom Nginx config file, copy `roles/apps/templates/nginx_site_config_default.j2` to `roles/apps/templates/nginx_site_config_{{ app.name }}.j2` and customise that. NOTE: Not currently working see https://github.com/philgyford/ansible-playbook/issues/9

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
├── myapplication/
│   ├── __init__.py
│   ├── media/
│   ├── static_collected/
│   ├── settings/
│   ├── templates/
│   ├── urls.py
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
