# OpenStack Deployment with Kolla-Ansible

This documentation explains how to deploy OpenStack using Kolla-Ansible, a tool that simplifies OpenStack deployment with containers. It covers the installation of dependencies, setting up the virtual environment, and configuring the system for deployment. The deployment will be executed step-by-step, as defined in the provided shell script.

### Prerequisites

--> A system running Ubuntu (or a compatible distribution).
--> Sudo privileges for the installation of dependencies.
--> Basic knowledge of Linux commands and system administration.


### Host machine requirements

The host machine must satisfy the following minimum requirements:

   -  at least 2 network interfaces ( internal, external)
   -  at least 8GB main memory
   -  at least 50GB disk space


## Step-by-Step OpenStack all-in-one Deployment

### 1. Updating and Installing Dependencies

This section updates the package lists and installs the necessary dependencies for the setup

sudo apt update -y && sudo apt-get full-upgrade -y
sudo apt install -y python3-dev libffi-dev gcc libssl-dev python3-selinux python3-setuptools python3-venv net-tools git



