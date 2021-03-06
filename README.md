# Ansible Multi-Django Playbook

Designed to host multiple Django websites, from different git repositories, on a single webserver. Can be used with a Vagrant virtual machine and a DigitalOcean droplet (not tested with anything else).

If you only want to host a single Django site on one (or more) machine(s) you're probably better off with something like [ansible-django-stack](https://github.com/jcalazan/ansible-django-stack).

This isn't a blank canvas but the playbook I use for my own sites. However, it's built with ease-of-reuse in mind.

**Contents:**

* Overview
* Customising for your own use
* Apps
* Running the playbook
* Environments
* AWS Command Line Interface
* Services


## Overview

The playbook will set up a server with Nginx, Gunicorn, Supervisor, Postgresql, Memcached, Fail2ban, AWS CLI, and Python (using pyenv). It can then set up one *or more* "apps" (Django websites), each from a different git repo, with their own domain name(s), own version of Python, own virtualenvs, own environment variables, Nginx config, Postgresql database, cron tasks, etc.

Most of the roles (`common`, `fail2ban`, `memcached`, etc.) set up the basic things on the server that will be used by all of the apps. No app-specific configuration is included in those roles.

The `apps` role installs and configures things particular to the apps. The basic configuration for the apps is set in an `apps` array in `group_vars/all/apps.yml` -- each app has its own dictionary of settings there.

There are some secret variables that are set in the `group_vars/all/vault.yml` file and then used within `group_vars/all/apps.yml`. This file can either be ignored by git (as it is at the moment) or else encrypted with ansible-vault.


## Customising for your own use

To use it for yourself:

1. Copy `group_vars/all/vault_example.yml` to `group_vars/all/vault.yml`
2. Set the `ubuntu_deploy_password` variable in `vault.yml` (using instructions in that file).
3. See if there are any variables you want to change in the `env_vars/*.yml` files.
4. Change IP addresses in `inventories/*.ini` files to reflect your own servers. (See "Environments", below, for more on Vagrant and DigitalOcean.)
5. Replace the `apps` vars in `group_vars/all/apps.yml` with those needed for your app(s). (See "Apps", below.)


## Apps

Each app should have a unique name, using only alphanumeric characters. This is used as its `name` in `group_vars/all/apps.yml`. In all the examples below we use `appname` as a placeholder for this.

To add a new app (ie, a new Django website on a new domain):

1. Add its config to `group_vars/all/apps.yml` (see below for options).
2. Add its secret config to `group_vars/all/vault.yml` (see further below).
3. If it uses a virtualenv, create a `roles/apps/templates/env_appname.j2` file (replacing `appname` in the filename) to hold the environment variables.
4. If you want a custom Nginx config file, copy `roles/apps/templates/nginx_site_config_default.j2` to `roles/apps/templates/nginx_site_config_appname.j2` and customise that. **NOTE:** Not currently working, see [this issue](https://github.com/philgyford/ansible-multi-django/issues/9).
5. To use with Vagrant, set a synced folder for each app in the `Vagrantfile`.
6. Check your Django site's file structure matches that outlined below.
7. Cross your fingers and run the playbook.

By default, the app's repo will be checked out to `/webapps/appname/`.

Logs for each app can be found at:

* `/var/log/cron/appname.log`
* `/var/log/nginx/appname_access.log`
* `/var/log/nginx/appname_error.log`
* `/var/log/supervisor/appname_gunicorn.log`

A python virtualenv will be created at `/home/deploy/.pyenv/versions/appname`. If the repo has a `runtime.txt` file whose first line is like `python-2.7.11` then that python version will be used in the virtualenv. Otherwise, the `default_python_version` will be used.

(That virtualenv path, and subsequent examples, assumes your `ubuntu_deploy_user` is `deploy`.)


### App config

You'll need to alter `group_vars/all/apps.yml` to reflect your websites. The `apps` variable looks something like this:

```yaml
apps:
  - name: 'appname'
	git_repo: 'https://github.com/my-name/my-repo.git'
	git_repo_branch: 'master'
	pip_requirements_file: 'requirements.txt'
    packages:
      - libjpeg8-dev
      - zlib1g-dev
	db_type: 'postgresql'
	db_password: '{{ vault.appname.db_password }}'
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
		loglevel: 'debug'
		max_requests: 1
  - name: 'anotherapp'
	git_repo: 'https://github.com/my-name/my-other-repo.git'
	# etc...
```

The presence of many of these options determines which tasks will be run for the app. eg, if `db_type` is present then a database will be created; otherwise it won't. The options:

* `name`: Required. Must be alphanumeric only. Must be unique. Depending on other options, will be used as directory names, virtualenv name, database name and user, etc.

* `git_repo`: Optional. The `https://github.com...` path to the git repository. It won't work with a `git@github.com...` path. Although optional, not much will happen without this.

* `git_repo_branch`: Optional. The name of the branch to check out. If omitted, defaults to `'master'`.

* `pip_requirements_file`: Optional. If the app has a pip requirements file, set the path to it within the repo here. eg, `requirements.txt`. Otherwise, omit this. If set, the python packages will be installed in the app's virtualenv.

* `packages`: Optional. A list of package names to be installed with apt. Useful if your app requires some packages that aren't installed by the generic package installing task.

* `db_type`: Optional. Currently must be 'postgresql' if present.

* `db_password`: Optional. Password for the database. Database name and username will be the same as the app's `name`.

* `allowed_hosts`: Optional. A dictionary with keys of environment names (eg, `production`) each one with an array of allowed hostnames. eg, `production: ['example.org', 'www.example.org']`. Used in Nginx config and, if you like, in your optional `env_appname.j2` template.

* `django_settings_module`: Optional. A dictionary with keys of environment names (eg, `production`) and the Python path to the settings file within the app. eg, `production: 'myproject.settings.live'`.

* `nginx_config`: Optional. If present, the site will have its Nginx site enabled. We don't currently use any settings in here, so it should be set to an empty dictionary (`{}`).

* `gunicorn_config`: Optional. If present Gunicorn and Supervisor will be set up.

    Within, there should be one dictionary per environment (eg, `production`), each containing config variables:
    * `loglevel`: Optional, default `"info"'. One of debug, info, warning, error, critical.
    * `max_requests`: Optional, default `1000`.
    * `num_workers`: Optional, default `3`.
    * `timeout_seconds`: Optional, default `30`.


### Vaulted config

Copy the `group_vars/all/vault_example.yml` to `group_vars/all/vault.yml` and edit is as needed. `vault.yml` is ignored by `.gitignore`, and contains variables that should be kept secret.

We can then use these secret variables in tasks but also within the main `apps` variable structure, which can be kept in git unencrypted. eg, in `vault.yml` we might have:

```yaml
vault:
  appname:
	db_password: 'secretpassword'
```

And in `apps.yml` we can use that password like this:

```yaml
apps:
  - name: 'appname'
	db_password: '{{ vault.appname.db_password }}'
```

Instead of having the `vault.yml` file `.gitignore`d, you could encrypt it instead. Do that with:

```shell
$ ansible-vault encrypt group_vars/all/vault.yml
```

Edit it with:

```shell
$ ansible-vault edit group_vars/all/vault.yml
```

You would then need to add the `--ask-vault-pass` argument whenever you use `ansible-playbook` (see below).


### Cron

If an app has a `cron.txt` file in its root, and `ubuntu_use_cron` is set to true, then this file will be copied to `/etc/cron.d/appname.txt`. A `cron.txt` file might look something like:

```shell
SHELL=/bin/bash
APP_ENV=/home/deploy/.pyenv/versions/appname
APP_HOME=/webapps/appname
LOGFILE=/var/log/cron/appname.log

01 04 * * * deploy source $APP_HOME/.env && $APP_ENV/bin/python $APP_HOME/manage.py my_task --foo=bar >> $LOGFILE 2>&1
```

Which will run the `my_task` Django management command with `foo=bar` arguments at 4:01am every day.

NOTE: Each cron task line must include the deploy username (which will run the task) after the five time-based fields. This is different to the standard crontab task format.

The file paths match those set by the playbook. It's a bit annoying that they're hard-coded here, but there we go.


### Django sites

We assume this structure for Django sites, eg:

```shell
/webapps/
├── appname/
    ├── appname/
    │   ├── __init__.py
    │   ├── media/
    │   ├── static_collected/
    │   ├── settings/
    │   ├── templates/
    │   │   └── 500.html
    │   ├── urls.py
    │   └── wsgi.py
    ├── cron.txt    # optional
    ├── manage.py
    ├── requirements.txt
    └── runtime.txt
```

Note that `manage.py` must have `#!/usr/bin/env python` as its shebang, and must be executable.


#### Importing an existing Django database

By default a new database will be created for the app and the Django database migrations will be run. If you subsequently need to import a database from an existing version of the site, this could cause problems -- for example, I've had Django's content-types not match up when importing data.

We'll assume a database has been dumped from an existing version of the site, and sent to S3 using this:

```shell
$ pg_dump -Fc --no-acl -h localhost -U appname appname > YOUR-PGDUMP-FILE
$ aws s3 cp YOUR-PGDUMP-FILE s3://BUCKETNAME/DIRECTORY/YOUR-PGDUMP-FILE
```

1. Delete the database that was created by the Django migrations. On the server/Vagrant, while logged in as `deploy` (requires the deploy user's password):

	```shell
	$ sudo su - postgres
	postgres$ dropdb appname
	```

2. On the local machine, run the postgresql tasks for that app, which will (re)create the now missing database, but not run the Django migrations:

	```shell
	$ ./run-playbook.sh -e vagrant -t postgresql -a appname
	```

3. Back on the server/Vagrant, fetch the dump from S3, if that's where your file is, and put it on your server/Vagrant somewhere:

4. Still on the server/Vagrant, import the file's contents into the database. eg, depending on your requirements (requires the app's database password, probably set in `group_vars/all/vault.yml`):

	```shell
	$ pg_restore -Fc -h localhost -d appname -U appname -W YOUR-PGDUMP-FILE
	```


#### Django media files

If your site has any existing media files (eg, images uploaded through Django admin) you may need to manually copy them into the correct location. For example, assuming we're copying the local directory to 188.166.146.145 using port 1025:

```shell
$ scp -P 1025 -r ./media deploy@188.166.146.145:/webapps/appname/appname/media
```


## Running the playbook

The playbook is run with the `ansible-playbook` command. There is a shortcut shell script included, `run-playbook.sh`. Instructions for Vagrant or DigitalOcean are below.


### Restricting ansible-playbook to a single app

When the playbook is run, the `apps` tasks will cycle through each of the apps listed in the config and perform the task for each one.

Any of the `ansible-playbook` commands below can be restricted to a single app by using `extra-vars`. eg:

```shell
$ ansible-playbook [other args here] --extra-vars="app=appname"
```

That will only run the `apps` tasks for the `appname` app. Note that this argument is actually a regular expression. So `app=appname` would match `appname` and `appname2`. Or you could specify multiple apps by doing `app=app1|app2|app3`.

If using the shell script, you can restrict it to a single app with the `-a/--app` option, eg:

```shell
$ ./run-playbook.sh --env vagrant --tags "foo,bar" --app appname
```

or:

```shell
$ ./run-playbook.sh -e vagrant -t "foo,bar" -a appname
```


### Deploying code changes

If you only need to update the code on an existing server, use the `deploy` tag. eg, for a single app on the production environment:

```shell
$ ./run-playbook.sh -e production -t deploy -a appname
```

You may need to restart Gunicorn manually, using Supervisor, afterwards (see "Services" below).


### Command line work

If you're logged in as the `deploy` user and:

```shell
    $ cd /webapps/appname
```

then the virtual environment should be activated automatically, and the `.env` file used to create environment variables.

If you're logged in as a different user, this won't happen (permisisons issue?). In this case, to get the correct environment and its variables:

```shell
    $ . /home/deploy/.pyenv/versions/appname/bin/activate
    $ . /webapps/appname/.env
```


## Environments

If you need to create a new environment, you'll need to create new files at:

* `env_vars/newenv.yml`
* `inventories/newenv.ini`
* `newenv.yml`

Copy existing files. The `newenv.yml` will need to refer to the `env_vars/newenv.yml` variable file.

Also be sure to set any environment-specific variables in `group_vars/all/apps.yml` eg, `gunicorn_config`) or tasks will break when looking for it.

*And* you'll need to add a clause to `run-playbook.sh` to handle the new environment name.


### Vagrant

To create the Vagrant box:

```shell
$ vagrant up
```

To subsequently run ansible over the box again, with all tags and apps:

```shell
$ vagrant provision
```

Or:

```shell
$ ./run-playbook.sh -e vagrant
```

Which will let you specify tags and apps:

```shell
$ ./run-playbook.sh -e vagrant -t "foo,bar" -a appname
```

Once it's run you can ssh in to Vagrant using the `deploy` user (using the IP address set in `Vagrantfile` and `inventories/vagrant.ini`):

```shell
$ ssh deploy@192.168.33.15
```

or as the standard `vagrant` user:

```shell
$ vagrant ssh
```

#### Differences with other environments

The Vagrant environment isn't quite like a standard server. The differences are based on the current settings in `env_vars/vagrant.yml`. The differences are:

* No `/webapps/[appname]` directories are created, because we use synced folders.
* No git repo is checked out for each app, because we use the contents of synced folders instead.
* The firewall isn't configured.
* SSH isn't restricted to a single port.
* Fail2Ban isn't set up.
* Each app's `cron.txt` file isn't copied to `/etc/cron.d/`.
* Each app's database user has permission to create databases (so that Django can do so when running tests).
* Memcached's log is verbose


### DigitalOcean

These steps assume you're using the `production` environment. Just change that to whatever environment you're using if it's not that.

1. Have an SSH key set on your account: https://www.digitalocean.com/community/tutorials/how-to-use-ssh-keys-with-digitalocean-droplets

2. Create a new Ubuntu 14.04 x64 droplet, clicking the checkbox to add your SSH key (or add a new one).

3. You should now be able to do this (in this and subsequent examples, change the IP address to your droplet's of course):

	```shell
	$ ssh root@188.166.146.145
	```

4. Put the droplet's IP address in `inventories/production.ini`. eg:

	```ini
	[webservers]
	188.166.146.145
	```

5. Run the playbook (note, this first time we specify the user as `root`):

	```shell
	$ ansible-playbook --inventory-file=inventories/production.ini --user=root -v production.yml
	```

6. It should be all done. If the variable `ubuntu_use_firewall` is true (set in `env_vars/*.yml`), then you'll only be able to SSH to the `ubuntu_ssh_port` as the `ubuntu_deploy_user` eg, if the user is `deploy` and `ubuntu_ssh_port` is `1025`:

	```shell
	$ ssh deploy@188.166.146.145 -p 1025
	```

	These should fail (although the first will work if `ubuntu_ssh_port` is `22`):

	```shell
	$ ssh deploy@188.166.146.145
	$ ssh root@188.166.146.145 -p 1025
	```

7. If the SSH port has now changed from 22 (as in the previous step), you'll need to add it to `inventories/production.ini`. eg:

	```ini
	[webservers]
	188.166.146.145:1025
	```

8. For subsequent runs, you'll need to set ansible-playbook to use the `ubuntu_deploy_user`, use `--sudo` to become sudo, and `--ask-sudo-pass` to be prompted for the sudo password (set in an `env_vars/*.yml` file):

	```shell
	$ ansible-playbook --inventory-file=inventories/production.ini --user=deploy --sudo  -v --ask-sudo-pass production.yml
	```

    Or, using the provided shell script:

	```shell
	$ ./run-playbook.sh -e production
	```


## AWS Command Line Interface

By default the [AWS CLI](https://aws.amazon.com/documentation/cli/) is installed. A virtualenv is created using pyenv before installing the python `awscli` package. Prevent installation by setting the `ubuntu_use_awscli` variable in `env_vars/base.yml` to `no`.

Configuration happens in the same file, where there are two settings:

	awscli_output_format: 'json'
	awscli_region: 'eu-west-1'

The vaulted config files contain the AWS key and secret.

	awscli_access_key_id: 'YOUR-KEY-HERE'
	awscli_secret_access_key: 'YOUR-SECRET-HERE'

If you SSH into your server/vagrant you should be able to do things like this, depending on the permissions of your AWS user. i.e. activate the python virtual environment containing the command, list the contents of an S3 directory, and copy a local file to it:

	$ pyenv activate awscli
	(awscli) $ aws ls s3://your-bucket-name/directory-name
	(awscli) $ aws cp your-local-file.txt s3://your-bucket-name/directory-name/


## Services

How to start, stop and inspect various services and things. Because I'll never remember all this.

As mentioned above, logs for each app can be found at:

Logs for each app can be found at:

* `/var/log/cron/appname.log`
* `/var/log/nginx/appname_access.log`
* `/var/log/nginx/appname_error.log`
* `/var/log/supervisor/appname_gunicorn.log`


### Maintenance mode

Switch any app into maintenance mode by doing this (with your deploy username and appname):

```shell
$ mv /home/deploy/.pyenv/versions/appname/maintenance_off.html /home/deploy/.pyenv/versions/appname/maintenance_on.html
```

All requests to that site will return `503` and that HTML page until the file is moved back.


### Nginx

Start, stop, or restart Nginx (which handles incoming HTTP requests):

```shell
$ sudo service nginx start
$ sudo service nginx stop
$ sudo service nginx restart
```


### Supervisor

Supervisor runs the Gunicorn processes, which serve the Django app(s). Log in as `deploy` and then open supervisorctl to see the processes:

```shell
$ sudo supervisorctl
appname_gunicorn              RUNNING    pid 14708, uptime 0:42:06
```

Control processes using their name:

```shell
supervisor> stop appname_gunicorn
supervisor> start appname_gunicorn
supervisor> restart appname_gunicorn
```

Or just run the commands directly:

```shell
$ sudo supervisorctl status appname_gunicorn
$ sudo supervisorctl restart appname_gunicorn
```


### Memcached

Restart Memcached like:

```shell
$ sudo /etc/init.d/memcached restart
```

See some stats (assuming it's running on default IP and port):

```shell
$ echo stats | nc 127.0.0.1 11211
```

You can do this to see it change:

```shell
$ watch "echo stats | nc 127.0.0.1 11211"
```


### Fail2Ban

[Fail2Ban](http://www.fail2ban.org) is optionally used with the Nginx server to ban people who request certain things too often. Enable/disable it with the `ubuntu_use_fail2ban` variable in `env_vars/*.yml` files, where there are also some configuration variables.

This will get a list of the different jails used:

```shell
$ sudo fail2ban-client status
```

Then for any one of the jails you can get more detail:

```shell
$ sudo fail2ban-client status nginx-http-auth
```

Remove an IP address from a jail:

```shell
$ sudo fail2ban-client set nginx-http-auth unbanip 111.111.111.111
```
