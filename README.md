# OpenStack Deployment with Kolla-Ansible

This documentation explains how to deploy OpenStack using Kolla-Ansible, a tool that simplifies OpenStack deployment with containers. It covers the installation of dependencies, setting up the virtual environment, and configuring the system for deployment. The deployment will be executed step-by-step, as defined in the provided shell script.

### Prerequisites

  - A system running Ubuntu (or a compatible distribution).
  - Sudo privileges for the installation of dependencies.
  - Basic knowledge of Linux commands and system administration.

### Host machine requirements

The host machine must satisfy the following minimum requirements:

   -  at least 2 network interfaces ( internal, external)
   -  at least 8GB main memory
   -  at least 50GB disk space


## Step-by-Step OpenStack all-in-one Deployment

### 1. Updating and Installing Dependencies

This section updates the package lists and installs the necessary dependencies for the setup
<sub>
   sudo apt update -y && sudo apt-get full-upgrade -y
   sudo apt install -y python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv net-tools git
</sub>


### 2. Setting Up Python Virtual Environment

python3 -m venv "kolla-venv"

Activate the virtual environment:

source kolla-venv/bin/activate

### 3. Installing Python Packages

pip install -U pip
pip install wheel dbus-python docker

### 4. Installing Ansible and Kolla-Ansible

pip install "ansible-core>=2.15,<2.16.99"
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2024.1

Ansible is used for automation, and Kolla-Ansible is a collection of Ansible playbooks and roles to deploy OpenStack with Docker containers.

### 5. Configuring Ansible

The script configures Ansible to avoid host key checking and increase parallelism for tasks:

sudo mkdir -p /etc/ansible
sudo nano /etc/ansible/ansible.cfg

pass this into the ansible.cfg:

[defaults]
host_key_checking=False
pipelining=True
forks=100
EOF


### 6. Install Kolla-Ansible

pip install git+https://opendev.org/openstack/kolla-ansible@stable/2024.1

### 7. Set up Kolla-Ansible directory and ensure ownership

sudo mkdir -p /etc/kolla  # Create Kolla-Ansible directory
sudo chown $USER:$USER /etc/kolla  # Change ownership to the current user

### 8. Copying configuration files 

cp -r "$HOME/kolla-venv/share/kolla-ansible/etc_examples/kolla/"* /etc/kolla  # Copy example configuration files
cp "$HOME/kolla-venv/share/kolla-ansible/ansible/inventory/"* .  # Copy inventory files


### 9. Checking if configurations are OK by performing a ping test

ansible --version
ansible -i ./all-in-one all -m ping  # Ping the hosts to verify Ansible is working


### 10. Generate passwords for Kolla-Ansible

kolla-genpwd

### 11. Change keystone_admin_password to "kolla" in passwords.yml

sed -i 's#keystone_admin_password:.*#keystone_admin_password: kolla#g' /etc/kolla/passwords.yml 


### 12. Configuring Kolla globals.yml with internal IP addresses

sudo nano /etc/kolla/globals.yml

copy this:

workaround_ansible_issue_8743: yes
kolla_base_distro: "ubuntu"
openstack_release: "2024.1"
network_interface: "enp0s8"
neutron_external_interface: "enp0s9"
kolla_internal_vip_address: "192.168.50.5"  # Set internal VIP address
enable_haproxy: "no"  # Disable HAProxy by default
nova_compute_virt_type: "qemu"  # Set default virtualization type for Nova

#### fqdn
kolla_external_fqdn: "opkext.test.link"  # Set external FQDN (optional)
kolla_internal_fqdn: "opkint.test.link"  # Set internal FQDN (optional)

#### cinder
#enable_cinder: "yes"  # Enable Cinder volume service (optional)
#enable_cinder_backend_lvm: "yes"  # Enable LVM backend for Cinder (optional)
#cinder_volume_group: "cinder-volumes"  # Set Cinder volume group (optional)
#enable_cinder_backup: "no"  # Disable Cinder backup service (optional)

#### tls 
kolla_enable_tls_internal: "yes"
kolla_enable_tls_external: "yes"
kolla_certificates_dir: "/etc/kolla/certificates"
kolla_external_fqdn_cert: "{{ kolla_certificates_dir }}/haproxy.pem"
kolla_internal_fqdn_cert: "{{ kolla_certificates_dir }}/haproxy-internal.pem"
kolla_admin_openrc_cacert: "/etc/ssl/certs/ca-certificates.crt"
kolla_copy_ca_into_containers: "yes"
openstack_cacert: "/etc/ssl/certs/ca-certificates.crt"


kolla_enable_tls_backend: "yes"
kolla_verify_tls_backend: "yes"
kolla_tls_backend_cert: "{{ kolla_certificates_dir }}/backend-cert.pem"
kolla_tls_backend_key: "{{ kolla_certificates_dir }}/backend-key.pem"


### 13. Installing Ansible Galaxy dependencies

kolla-ansible install-deps

### 14. check if docker is installed 

docker --version

### 15. Add current user to docker group 

sudo usermod -aG docker $USER


### 16. Starting the Deployment Process

The deployment process starts by bootstrapping the servers, running prechecks, and deploying OpenStack services using Kolla-Ansible:

#### Destroying previous deployment (if any)...

kolla-ansible destroy --yes-i-really-really-mean-it -i ./all-in-one


#### Generating new certificates...

kolla-ansible certificates -i ./all-in-one  # Optionally generate new certificates
sudo cp /etc/kolla/certificates/ca/root.crt /usr/local/share/ca-certificates/kolla-root.crt # important if making it https
sudo update-ca-certificates

#### Bootstrapping the servers...

kolla-ansible bootstrap-servers -i ./all-in-one -e ansible_sudo_pass=yoursystempassword

#### Running prechecks...

kolla-ansible prechecks -i ./all-in-one  # Run prechecks before deploying


####  Running Deployment...

kolla-ansible deploy -i ./all-in-one

#### Running Post Deployment...

kolla-ansible post-deploy


### Installing Openstack Client:

pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-neutronclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-glanceclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-heatclient -c https://releases.openstack.org/constraints/upper/2024.1



### check the server:

source /etc/kolla/admin-openrc.sh
source /etc/kolla/admin-opnerc-system.sh

openstack server list
