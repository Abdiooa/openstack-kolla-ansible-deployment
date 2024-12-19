#!/bin/bash

#set -e
#exec > setup.log 2>&1

# Function to log messages
log_message() {
    echo "[INFO] $1"
}

# Start the setup process
log_message "Starting the setup process..."

# Update and install dependencies
log_message "Updating package lists and upgrading existing packages..."
sudo apt update -y && sudo apt-get full-upgrade -y  # Update package list and upgrade any installed packages

log_message "Installing required dependencies..."
# Install necessary dependencies for Kolla-Ansible setup
sudo apt install -y python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv net-tools git

# Check if virtual environment exists, if not, create and activate it
VENV_DIR="kolla-venv"
if [ ! -d "$VENV_DIR" ]; then
    log_message "Virtual environment not found. Creating one..."
    python3 -m venv "$VENV_DIR"  # Create a Python virtual environment for Kolla-Ansible
fi

log_message "Activating virtual environment..."
source "$VENV_DIR/bin/activate"  # Activate the virtual environment

# Upgrade pip and install required Python packages
log_message "Upgrading pip and installing wheel..."
sudo apt install -y python3-docker  # Install Docker Python package
pip install -U pip  # Upgrade pip
pip install wheel  # Install wheel for package building


log_message "docker setup"l
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo apt update
sudo apt update
sudo usermod -aG docker ${USER}
docker --version

#sudo apt install docker.io -y  # Optionally install Docker if not installed

log_message "Setup complete."

# Variables for Ansible and Kolla-Ansible versions and configurations
ANSIBLE_CORE_VERSION_MIN=2.15
ANSIBLE_CORE_VERSION_MAX=2.16
KOLLA_BRANCH_NAME="stable/2024.1"

# Install ansible-core with specific version
log_message "Installing Ansible-Core version ${ANSIBLE_CORE_VERSION_MIN} to ${ANSIBLE_CORE_VERSION_MAX}..."
pip install "ansible-core>=$ANSIBLE_CORE_VERSION_MIN,<${ANSIBLE_CORE_VERSION_MAX}.99"  # Install the required Ansible version

# Configure Ansible settings
log_message "Configuring Ansible settings..."
sudo mkdir -p /etc/ansible  # Create Ansible configuration directory
sudo tee /etc/ansible/ansible.cfg > /dev/null << EOF
[defaults]
host_key_checking=False
pipelining=True
forks=100
EOF

# Install Kolla-Ansible from a specific Git branch
log_message "Installing Kolla-Ansible from branch $KOLLA_BRANCH_NAME..."
pip install git+https://opendev.org/openstack/kolla-ansible@$KOLLA_BRANCH_NAME  # Optionally install from Git branch
#pip install kolla-ansible  # Install the Kolla-Ansible package

# Set up Kolla-Ansible directory and ensure ownership
log_message "Setting up Kolla-Ansible directory and ensuring proper ownership..."
sudo mkdir -p /etc/kolla  # Create Kolla-Ansible directory
sudo chown $USER:$USER /etc/kolla  # Change ownership to the current user

# Copy configuration files if they exist in the virtual environment
if [ -d "$HOME/kolla-venv/share/kolla-ansible/etc_examples/kolla" ]; then
    log_message "Copying Kolla-Ansible configuration files..."
    cp -r "$HOME/kolla-venv/share/kolla-ansible/etc_examples/kolla/"* /etc/kolla  # Copy example configuration files
    cp "$HOME/kolla-venv/share/kolla-ansible/ansible/inventory/"* .  # Copy inventory files
else
    log_message "Kolla-Ansible configuration directories not found. Check installation."
    exit 1  # Exit if configuration files are missing
fi

# Checking if configurations are OK by performing a ping test
log_message "Checking Ansible configuration with a ping test..."
ansible --version
ansible -i ./all-in-one all -m ping  # Ping the hosts to verify Ansible is working

# Generate passwords for Kolla-Ansible
log_message "Generating Kolla passwords..."
if kolla-genpwd; then
    log_message "Password generation successful."
else
    log_message "Failed to generate Kolla passwords."  # Log failure if password generation fails
fi

# Change keystone_admin_password to "kolla" in passwords.yml
log_message "Updating keystone_admin_password in passwords.yml..."
sed -i 's#keystone_admin_password:.*#keystone_admin_password: kolla#g' /etc/kolla/passwords.yml  # Uncomment to change password

# Get the internal IP address of enp0s9 interface
my_br_ip=$(ifconfig enp0s8 | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'  | cut -d' ' -f2)
br2_ip=$(ifconfig enp0s9 | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'  | cut -d' ' -f2)

echo $my_br_ip  # Display internal IP address
echo $br2_ip  # Display external IP address

# Configure Kolla globals.yml with detected internal IP address
log_message "Configuring Kolla globals.yml..."
sudo tee /etc/kolla/globals.yml > /dev/null << EOF
---
workaround_ansible_issue_8743: yes
kolla_base_distro: "ubuntu"
openstack_release: "2024.1"
network_interface: "enp0s8"
neutron_external_interface: "enp0s9"
kolla_internal_vip_address: "192.168.50.5"  # Set internal VIP address
enable_haproxy: "no"  # Disable HAProxy by default
nova_compute_virt_type: "qemu"  # Set default virtualization type for Nova

## fqdn
kolla_external_fqdn: "opkext.test.link"  # Set external FQDN (optional)
kolla_internal_fqdn: "opkint.test.link"  # Set internal FQDN (optional)

## cinder
#enable_cinder: "yes"  # Enable Cinder volume service (optional)
#enable_cinder_backend_lvm: "yes"  # Enable LVM backend for Cinder (optional)
#cinder_volume_group: "cinder-volumes"  # Set Cinder volume group (optional)
#enable_cinder_backup: "no"  # Disable Cinder backup service (optional)

## tls 
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


EOF

# Deactivate the virtual environment
deactivate
log_message "Setup complete. Please check the logs for details."

# Deployment process
log_message "Starting the deployment process..."

source kolla-venv/bin/activate  # Re-activate the virtual environment for deployment

# Install Ansible Galaxy dependencies
log_message " Installing Ansible Galaxy dependencies..."
kolla-ansible install-deps  # Install required dependencies for Kolla-Ansible

echo docker --version  # Check Docker version

# Add devops user to docker group (if not already added)
log_message "Adding devops user to the docker group..."
if ! groups devops | grep &>/dev/null '\bdocker\b'; then
    sudo usermod -aG docker $USER  # Add user to Docker group
    log_message "User devops added to docker group."
else
    log_message "User devops is already in the docker group."
fi
sudo usermod -aG docker $USER

log_message "Destroying previous deployment (if any)..."
kolla-ansible destroy --yes-i-really-really-mean-it -i ./all-in-one  # Destroy previous Kolla-Ansible deployment

log_message "Generating new certificates..."
kolla-ansible certificates -i ./all-in-one  # Optionally generate new certificates
sudo cp /etc/kolla/certificates/ca/root.crt /usr/local/share/ca-certificates/kolla-root.crt # important if making it https
sudo update-ca-certificates


log_message "Bootstrapping the servers..."
kolla-ansible bootstrap-servers -i ./all-in-one -e ansible_sudo_pass=devops  # Bootstrap servers for deployment

log_message "Running prechecks..."
kolla-ansible prechecks -i ./all-in-one  # Run prechecks before deploying

log_message "Running Deployment..."
kolla-ansible deploy -i ./all-in-one



log_message "Running Post Deployment..."
kolla-ansible post-deploy


pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-neutronclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-glanceclient -c https://releases.openstack.org/constraints/upper/2024.1

pip install python-heatclient -c https://releases.openstack.org/constraints/upper/2024.1