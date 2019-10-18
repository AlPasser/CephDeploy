# 参考链接：https://docs.ceph.com/docs/mimic/start/quick-start-preflight/#ceph-node-setup
# 以下操作都是在 UBUNTU 16.04 上进行的

# 在 admin node 上安装 ceph-deploy
# 1. Add the release key
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
# 2. Add the Ceph packages to your repository
echo deb https://download.ceph.com/debian-{ceph-stable-release}/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
# 3. Update your repository and install ceph-deploy
sudo apt update
sudo apt install ceph-deploy

# 安装 NTP
# We recommend installing NTP on Ceph nodes (especially on Ceph Monitor nodes) to prevent issues arising from clock drift.
sudo apt install ntp

# 在所有的 Ceph Nodes 上安装 SSH server
sudo apt install openssh-server

# 在所有的 Ceph Nodes 上创建 ceph deploy 用户
# Create a user with passwordless sudo
# 1. Create a new user on each Ceph Node
ssh user@ceph-server
sudo useradd -d /home/{username} -m {username}
sudo passwd {username}
# 2. For the new user you added to each Ceph node, ensure that the user has sudo privileges
echo "{username} ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/{username}
sudo chmod 0440 /etc/sudoers.d/{username}
# The admin node must have password-less SSH access to Ceph nodes.
# Enable password-less ssh
# 1. Generate the SSH keys, but do not use sudo or the root user. Leave the passphrase empty
ssh-keygen
# 2. Copy the key to each Ceph Node, replacing {username} with the user name you created
ssh-copy-id {username}@node1
ssh-copy-id {username}@node2
ssh-copy-id {username}@node3
# (Recommended) Modify the ~/.ssh/config file of your ceph-deploy admin node so that ceph-deploy can log in to Ceph nodes as the user you created
# without requiring you to specify --username {username} each time you execute ceph-deploy.
# This has the added benefit of streamlining ssh and scp usage. Replace {username} with the user name you created:
Host node1
   Hostname node1
   User {username}
Host node2
   Hostname node2
   User {username}
Host node3
   Hostname node3
   User {username}

# Note: Hostnames should resolve to a network IP address, not to the loopback IP address (e.g., hostnames should resolve to an IP address other than 127.0.0.1).
# If you use your admin node as a Ceph node, you should also ensure that it resolves to its hostname and IP address (i.e., not its loopback IP address).

# Ceph Monitors communicate using port 6789 by default.
# Ceph OSDs communicate in a port range of 6800:7300 by default.