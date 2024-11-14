#!/bin/bash

# Update, upgrade and install dependencies
sudo apt update -y && sudo apt-get full-upgrade -y
sudo apt-get install -y python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv net-tools python3-docker

# Check if virtual environment exists, if not, create and activate it
if [ ! -d "kolla-venv" ]; then
    python3 -m venv kolla-venv
fi
source kolla-venv/bin/activate

# Upgrade pip and install dependencies
pip install -U pip
pip install wheel

# Install ansible-core with specific version
# Uncomment the line below when specifying the correct version of ansible-core
pip install 'ansible-core>=|ANSIBLE_CORE_VERSION_MIN|,<|ANSIBLE_CORE_VERSION_MAX|.99'

# Configure Ansible settings
sudo mkdir -p /etc/ansible
sudo tee /etc/ansible/ansible.cfg > /dev/null << EOF
[defaults]
host_key_checking=False
pipelining=True
forks=100
EOF

# Install Kolla-Ansible from a specific Git branch
pip install git+https://opendev.org/openstack/kolla-ansible@|KOLLA_BRANCH_NAME|

# Set up Kolla-Ansible directory and ensure ownership
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla

# Copy configuration files if they exist in the virtual environment
if [ -d "$HOME/kolla-venv/share/kolla-ansible/etc_examples/kolla" ]; then
    cp -r "$HOME/kolla-venv/share/kolla-ansible/etc_examples/kolla/"* /etc/kolla
    cp "$HOME/kolla-venv/share/kolla-ansible/ansible/inventory/"* .  # Fix path error
else
    echo "Kolla-Ansible configuration directories not found. Check installation."
    exit 1
fi

# Checking if Configurations are OK
ansible -i all-in-one -m ping

# Generate Password and change to "kolla"
kolla-genpwd || echo "Failed to generate Kolla passwords."
sed -i 's#keystone_admin_password:.*#keystone_admin_password: kolla#g' /etc/kolla/passwords.yml

# Configure Kolla globals.yml with detected internal IP address
my_br_ip=$(ip addr show enp0s9 | awk '/inet / {print $2}' | cut -d/ -f1)
my_br_ip=$(ifconfig enp0s9 | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'  | cut -d' ' -f2)
sudo tee /etc/kolla/globals.yml > /dev/null << EOF
---
workaround_ansible_issue_8743: yes
kolla_base_distro: "ubuntu"
openstack_release: "master"
network_interface: "enp0s9"
neutron_external_interface: "enp0s10"
kolla_internal_vip_address: "9.11.93.4"
kolla_external_vip_address: "192.168.56.3"
enable_haproxy: "no"
enable_neutron_provider_networks: "yes"
enable_openstack_core: "yes"
nova_compute_virt_type: "qemu"

## fqdn
kolla_external_fqdn: "opk.test.link"
kolla_internal_fqdn: "opkint.test.link"

## cinder
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
cinder_volume_group: "cinder-volumes"
enable_cinder_backup: "no"

## tls 
kolla_enable_tls_external: "yes"
kolla_copy_ca_into_containers: "yes"
openstack_cacert: "/etc/ssl/certs/ca-certificates.crt"
kolla_enable_tls_internal: "yes"
kolla_enable_tls_backend: "yes"
EOF

# Deployment process
source kolla-venv/bin/activate
kolla-ansible destroy --yes-i-really-really-mean-it -i ./all-in-one
kolla-ansible certificates -i ./all-in-one
kolla-ansible bootstrap-servers -i ./all-in-one -e ansible_sudo_pass=dadinos
kolla-ansible prechecks -i ./all-in-one
kolla-ansible deploy -i ./all-in-one
kolla-ansible post-deploy -i ./all-in-one
kolla-ansible check -i ./all-in-one


# Install Openstack Client
pip install python3-openstackclient
pip install python-magnumclient
source /etc/kolla/admin-openrc.sh
