# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"

  # IP address is the same as in inventories/vagrant
  config.vm.network :private_network, ip: "192.168.33.15"

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--name", "MyCoolApp", "--memory", "512"]
  end

  # Shared folder from the host machine to the guest machine. Uncomment the line
  # below to enable it.
  #config.vm.synced_folder "../../../my-cool-app", "/webapps/mycoolapp/my-cool-app"*/

  # Ansible provisioner.
  config.vm.provision "ansible" do |ansible|
    ansible.host_key_checking = false
    ansible.inventory_path = "inventories/vagrant.ini"
    ansible.limit = "webservers"
    ansible.playbook = "vagrant.yml"
    ansible.verbose = "v"
  end
end

