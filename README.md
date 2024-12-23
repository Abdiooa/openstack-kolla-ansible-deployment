# OpenStack Deployment with Kolla-Ansible

This documentation explains how to deploy OpenStack using **Kolla-Ansible**, a tool that simplifies OpenStack deployment with containers. It covers the installation of dependencies, setting up the virtual environment, and configuring the system for deployment. The deployment will be executed step-by-step using the provided shell script.

## Prerequisites

Before proceeding, ensure your system meets the following requirements:

- **Operating System**: Ubuntu 22.04 LTS or earlier.
- **Sudo Privileges**: Required for installing dependencies.
- **Knowledge**: Basic understanding of Linux commands and system administration.

## Host Machine Requirements

The host machine must satisfy the following minimum hardware requirements:

- At least **2 network interfaces** (internal and external).
- **8 GB of RAM** minimum.
- **50 GB of disk space** minimum.

## Step-by-Step OpenStack All-in-One Deployment

### [!WARNING] You do not need to perform these steps manually. After understanding them, you can simply run the script and it will automate the process.

### 1. **Download the Script**: Clone or download the deployment script repository.
   
### 2. **Make the Script Executable**:
  ```bash
   sudo chmod +x ./opkdeployment_script.sh
  ```
  then

  ```
  ./opkdeployment_cript.sh
  ```
### 1. Updating and Installing Dependencies

This section ensures that your system is up to date and installs the necessary dependencies for OpenStack deployment.

```bash
sudo apt update -y && sudo apt-get full-upgrade -y
sudo apt install -y python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv net-tools git
```
### 2. Setting Up Python Virtual Environment

We’ll create a virtual environment to isolate the deployment process:

```bash
python3 -m venv "kolla-venv"
```
Activate the virtual environment:
```bash
source kolla-venv/bin/activate
```
### 3. Upgrading pip and Installing Wheel

We upgrade pip and install wheel, a necessary package for building other dependencies:
```bash
pip install -U pip  # Upgrade pip
pip install wheel  # Install wheel for package building
```
### 4. Docker Setup

Kolla-Ansible uses Docker to run OpenStack services in containers. The following steps install Docker:
```
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce -y
sudo usermod -aG docker ${USER}

```
check Docker installation

```
docker --version
```


### 5. Installing and Configuring Ansible
Ansible is an open-source IT automation tool that simplifies and automates various manual IT processes, including provisioning, configuration management, application deployment, and orchestration. 
We will install it via pip:
```
pip install "ansible-core>=2.15,<2.16.99"
```
Configure Ansible to avoid host key checking and set parallelism for tasks by creating an ansible.cfg file:

```
sudo mkdir -p /etc/ansible
sudo nano /etc/ansible/ansible.cfg
```
Add the following configuration:
```
[defaults]
host_key_checking=False
pipelining=True
forks=100
EOF
```

### 6. Installing Kolla-Ansible
Kolla-Ansible is a collection of Ansible playbooks and roles to deploy OpenStack with Docker containers.
Install it via pip:
```
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2024.1
```

### 7. Set up Kolla-Ansible directory and ensure ownership
```
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
```

### 8. Copying configuration files 
Copy the example configuration files from the Kolla-Ansible virtual environment to the /etc/kolla directory:
```
cp -r "$HOME/kolla-venv/share/kolla-ansible/etc_examples/kolla/"* /etc/kolla
cp "$HOME/kolla-venv/share/kolla-ansible/ansible/inventory/"* .
```
### 9. Verifying Ansible Configuration
Verify that Ansible is installed correctly and can reach the hosts:
```
ansible --version
ansible -i ./all-in-one all -m ping  # Ping the hosts to verify Ansible is working
```

### 10. Generating Passwords for Kolla-Ansible

Generate passwords for Kolla-Ansible:
```
kolla-genpwd
```

### 11. Configure Passwords

Change the keystone_admin_password to "kolla" in the passwords.yml:
```
sed -i 's#keystone_admin_password:.*#keystone_admin_password: kolla#g' /etc/kolla/passwords.yml 
```
### 12. Configuring Kolla globals.yml 
```
sudo nano /etc/kolla/globals.yml
```
copy this, warning you discover more configurations in the globals file, here is here link:
```
https://github.com/openstack/kolla-ansible/blob/master/etc/kolla/globals.yml
```
```
workaround_ansible_issue_8743: yes
kolla_base_distro: "ubuntu"
openstack_release: "2024.1"
network_interface: "your_internal_network_interface"
neutron_external_interface: "your_external_network_interface"
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

```

### 13. Installing Ansible Galaxy dependencies
```
kolla-ansible install-deps
```
### 14. Verifying Docker Installation

Ensure that Docker is correctly installed:
```
docker --version
```
### 15. Adding the Current User to Docker Group

Ensure your user is part of the Docker group:
```
sudo usermod -aG docker $USER
```

And That is It!

-----------------------------------------------------------------------------------------------------------------

## Deployment Process

Now we begin the actual deployment process.
The deployment process starts by bootstrapping the servers, running prechecks, and deploying OpenStack services using Kolla-Ansible:


### 16. Destroy Previous Deployment (If Any)...

If there is a previous deployment, destroy it before proceeding:

```
kolla-ansible destroy --yes-i-really-really-mean-it -i ./all-in-one
```

### 17. Generate Certificates (If TLS Configured)

If you're using TLS, generate new certificates:
```
kolla-ansible certificates -i ./all-in-one  # Optionally generate new certificates
sudo cp /etc/kolla/certificates/ca/root.crt /usr/local/share/ca-certificates/kolla-root.crt # important if making it https
sudo update-ca-certificates
```

### 18. Bootstrap Servers

Bootstrap the servers (configure them to prepare for OpenStack services):
```
kolla-ansible bootstrap-servers -i ./all-in-one -e ansible_sudo_pass=yoursystempassword
```

### 19. Run Prechecks

Run prechecks to ensure everything is in order before deployment:
```
kolla-ansible prechecks -i ./all-in-one  # Run prechecks before deploying

```
### 20. Deploy OpenStack

Start the OpenStack deployment:
```
kolla-ansible deploy -i ./all-in-one
```
### 21. Post-Deployment Steps

After deployment, run the post-deployment tasks:

```
kolla-ansible post-deploy
```
And that is it, Openstack deployed on your system!

### 22. Installing OpenStack Client

To interact with OpenStack, install the necessary client tools:

```
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-neutronclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-glanceclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-heatclient -c https://releases.openstack.org/constraints/upper/2024.1
```


### check the server (running instances):
```
source /etc/kolla/admin-openrc.sh
source /etc/kolla/admin-opnerc-system.sh

openstack server list
```