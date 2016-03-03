# My first Ansible playbook

In progress.

Designed to host multiple websites, from different git repositories, on a single webserver. Can be used with a Vagrant virtual machine and a DigitalOcean droplet (not tested with anything else).

The `apps` role sets up things like databases, Nginx, Gunicorn, virtualenvs, directories, etc for each separate app (website) we've added configuration for. The other roles set up the basic machine, without app-specific things.


## To customise this for your own use

This isn't a blank canvas but the playbook I use for my own sites. However, it's built with ease-of-reuse in mind. To use it for yourself:

1. Replace the `apps` vars in `group_vars/all/apps.yml` with those needed for your apps.
2. Copy `group_vars/all/vault_example.yml` to `group_vars/all/vault.yml`
3. Set the `ubuntu_deploy_password` variable in `vault.yml` (using instructions in that file).
4. Change the `vault` vars to what you need.
5. To use with Vagrant, set a synced folder for each app in the `Vagrantfile`.

That might be it. See below for more details on all those variables and how to run the playbook.


## Apps

To add a new app (ie, a new website on a new domain):

1. Add its config to `group_vars/all/apps.yml` (see below for options).
2. Add its secret config to `group_vars/all/vault.yml` (see further below).
3. If it uses a virtualenv and needs environment variables set, create a `roles/apps/templates/env_appname.j2` file (where `appname` corresponds to `name` in the app's config).
4. If you want a custom Nginx config file, copy `roles/apps/templates/nginx_site_config_default.j2` to `roles/apps/templates/nginx_site_config_appname.j2` and customise that. **NOTE:** Not currently working, see [this issue](https://github.com/philgyford/ansible-playbook/issues/9).
4. To use with Vagrant, set a synced folder for each app in the `Vagrantfile`.
5. Cross your fingers and run the playbook.

By default, the app's repo will be checked out to `/webapps/appname/`.

Logs for each app can be found at:

    * `/var/log/nginx/appname_access.log`
    * `/var/log/nginx/appname_error.log`
    * `/var/log/supervisor/appname_gunicorn.log`

A python virtualenv will be created at `/home/deploy/.pyenv/versions/appname`. If the repo has a `runtime.txt` file whose first line is like `python-2.7.11` then that python version will be used in the virtualenv. Otherwise, the `default_python_version` will be used.

(Both those paths, and subsequent examples, assume your `ubuntu_deploy_user` (set in `env_vars/*.yml`) is `deploy`.)


### App config

You'll need to alter `group_vars/all/apps.yml` to reflect the websites (called "apps" here you want to install). The file looks something like this:

    ---
    apps:
      - name: 'myapp'
        git_repo: 'https://github.com/myname/myrepo.git'
        git_repo_branch: 'master'
        pip_requirements_file: 'requirements.txt'
        db_type: 'postgresql'
        db_password: '{{ vault.myapp.db_password }}'
        allowed_hosts:
          production: ['example.org', 'www.example.org']
          vagrant: ['example.dev', 'www.example.dev']
        django_settings_module:
          production: 'mydjangoapp.settings.production'
          vagrant: 'mydjangoapp.settings.vagrant'
        nginx_config: {}
        gunicorn_config:
          production:
            max_requests: 1000
            num_workers: 3
          vagrant:
            max_requests: 1
            loglevel: 'debug'
      - name: 'anotherapp'
        # etc...

The presence of many of these options determines which tasks will be run for the app. eg, if `db_type` is present then a database will be created; otherwise it won't. The options:

* `name`: Required. No spaces. Must be unique. Depending on other options, will be used as directory names, virtualenv name, database name and user, etc.

* `git_repo`: Optional. The `https://github.com...` path to the git repository. It won't work with a `git@github.com...` path. Although optional, not much will happen without this.

* `git_repo_branch`: Optional. The name of the branch to check out. If omitted, defaults to `'master'`.

* `pip_requirements_file`: Optional. If the app has a pip requirements file, set the path to it within the repo here. eg, `requirements.txt`. Otherwise, omit this. If set, the python packages will be installed.

* `db_type`: Optional. Currently must be 'postgresql' if present.

* `db_password`: Optional. Password for the database. Database name and username will be the same as the app's `name`.

* `allowed_hosts`: Optional. A dictionary with keys of environment names (eg, `production`) each one with an array of allowed hostnames. eg, `production: ['example.org', 'www.example.org']`. Used in Nginx config and maybe in your `env_appname.j2` template.

* `django_settings_module`: Optional. A dictionary with keys of environment names (eg, `production`) and the Python path to the settings file within the app. eg, `production: 'myproject.settings.live'`.

* `nginx_config`: Optional. If present, the site will have its Nginx site enabled. We don't currently use any settings in here, so it should be set to an empty dictionary (`{}`).

* `gunicorn_config`: Optional. If present Gunicorn and Supervisor will be set up.

    Within, there should be one dictionary per environment (eg, `production`), each containing config variables:
    * `loglevel`: Optional, default `"info"'. One of debug, info, warning, error, critical.
    * `max_requests`: Optional, default `1000`
    * `num_workers`: Optional, default `3`
    * `timeout_seconds`: Optional, default `30`


### Vaulted config

Copy the `group_vars/all/vault_example.yml` to `group_vars/all/vault.yml` and edit is as needed. `vault.yml` is ignored by `.gitignore`, and contains variables that should be kept secret.

We can then use these secret variables in tasks but also within the main `apps` variable structure, which can be kept in git unencrypted. eg, in `vault.yml` we might have:

    vault:
      pepysdiary:
    	db_password: 'secretpassword'

And in `apps.yml` we can use that password like this:

    apps:
	  - name: 'pepysdiary'
	    db_password: '{{ vault.pepysdiary.db_password }}'

Instead of having the `vault.yml` file `.gitignore`d, you could encrypt it instead. Do that with:

    $ ansible-vault encrypt group_vars/all/vault.yml

Edit it with:

    $ ansible-vault edit group_vars/all/vault.yml

You would then need to add the `--ask-vault-pass` argument whenever you use `ansible-playbook` (see below).


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
└── runtime.txt
```

(`myproject` is the same as the `name` variable in the `apps` config, above.)

Note that `manage.py` must have `#!/usr/bin/env python` as its shebang, and must be executable.


## Vagrant

To create the Vagrant box:

	$ vagrant up

To subsequently run ansible over the box again:

	$ vagrant provision

Or, possibly quicker:

	$ ansible-playbook --private-key=.vagrant/machines/default/virtualbox/private_key --user=vagrant --connection=ssh --inventory-file=inventories/vagrant.ini -v vagrant.yml

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
	$ ansible-playbook --inventory-file=inventories/production.ini --user=root -v production.yml
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
	$ ansible-playbook --inventory-file=inventories/production.ini --user=deploy --sudo  -v --ask-sudo-pass production.yml
	```


## Other notes

### Supervisor

Supervisor runs the Gunicorn processes. Log in as `deploy` and then open supervisorctl to see the processes:

    $ sudo supervisorctl
    appname_gunicorn              RUNNING    pid 14708, uptime 0:42:06

Control processes using their name:

    supervisor> stop appname_gunicorn
    supervisor> start appname_gunicorn
    supervisor> restart appname_gunicorn

Or just run the commands directly:

    $ sudo supervisorctl status appname_gunicorn
    $ sudo supervisorctl restart appname_gunicorn

### Fail2Ban

[Fail2Ban](http://fail2ban.org) is optionally used with the Nginx server to ban people who request certain things too often. Enable/disable it with the `ubuntu_user_fail2ban` variable in `env_vars/*.yml` files, where there is also some configuration variables.

This will get a list of the different jails used:

    $ sudo fail2ban-client status

Then for any one of the jails you can get more detail:

    $ sudo fail2ban-client status nginx-http-auth

Remove an IP address from a jail:

    $ sudo fail2ban-client set nginx-http-auth unbanip 111.111.111.111
