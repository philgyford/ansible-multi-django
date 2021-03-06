# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"

  # IP address is the same as in inventories/vagrant
  config.vm.network :private_network, ip: "192.168.33.15"

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--name", "AnsiblePlaybook", "--memory", "512"]
  end


  # Change the lines below to map from directories on the host (local) machine
  # to the guest (Vagrant) machine.

  # NOTE: The owner and group IDs should be the same as those set in
  # env_vars/*.yml files. Because of this problem:
  # http://ryansechrest.com/2014/04/unable-set-permissions-within-shared-folder-using-vagrant-virtualbox/

  # AND: guest path should be like /webapps/[appname]

  # AND: File permissions need to be 777 so that Django's manage.py file is
  # executable. There's no way of subsequently changing permissions within a
  # synced folder under VirtualBox.

  # AND: I had to do `vagrant reload` after adding a new synced_folder before
  # it was seen when Ansible ran using `vagrant provision`.

  config.vm.synced_folder "../../Projects/personal/django-ditto-demo/",
    "/webapps/dittodemo",
    owner: 5000, group: 5000, mount_options: ['dmode=775', 'fmode=777']

  config.vm.synced_folder "../../Projects/personal/django-pepysdiary/",
    "/webapps/pepysdiary",
    owner: 5000, group: 5000, mount_options: ['dmode=775', 'fmode=777']

  # Ansible provisioner.
  config.vm.provision "ansible" do |ansible|
    ansible.host_key_checking = false
    ansible.inventory_path = "inventories/vagrant.ini"
    ansible.limit = "webservers"
    ansible.playbook = "vagrant.yml"
    ansible.verbose = "v"
    # ansible.ask_vault_pass = true
  end
end
