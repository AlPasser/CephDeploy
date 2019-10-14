# 参考链接：https://docs.ceph.com/docs/mimic/start/quick-ceph-deploy/
# 以下操作都是在 UBUNTU 16.04 上进行的

# Create a directory on your admin node for maintaining the configuration files and keys that ceph-deploy generates for your cluster
mkdir ceph-cluster && cd ceph-cluster

# Important: Do not call ceph-deploy with sudo or run it as root if you are logged in as a different user, because it will not issue sudo commands needed on the remote host.

# 注意：以下最好使用主机的 hostname，否则可能出错

# Create the cluster
# Specify node(s) as hostname, fqdn or hostname:fqdn
# ceph-deploy new {initial-monitor-node(s)}
ceph-deploy new cloud08

# Install Ceph packages
# ceph-deploy install {ceph-node} [...]
ceph-deploy install cloud08 cloud-XIII cloud04
# apt-get update 出错时，需修改 /etc/apt/sources.list.d/ceph.list 为
deb https://download.ceph.com/debian-luminous/ xenial main
# apt-get install 因网络延迟超时时，可手动在每个节点上执行超时了的命令
# 默认的更新源很慢，可以将其调整为阿里云的更新源，修改 /etc/apt/sources.list.d/ceph.list 为
deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted
deb http://mirrors.aliyun.com/ubuntu/ xenial universe
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates universe
deb http://mirrors.aliyun.com/ubuntu/ xenial multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu xenial-security main restricted
deb http://mirrors.aliyun.com/ubuntu xenial-security universe
deb http://mirrors.aliyun.com/ubuntu xenial-security multiverse
deb https://download.ceph.com/debian-luminous/ xenial main
# 以上也可用 deb http://download.ceph.com/debian-luminous/ xenial main
# 需要添加 release key
wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
# 如果还不能解决，需参考 https://www.cnblogs.com/xiao987334176/p/9909039.html
# 一个有效的方法，在每个节点上运行
sudo apt-get install -y radosgw --allow-unauthenticated
sudo apt-get install ceph ceph-mds
# 也可采用离线 deb 安装法（最有效），在 admin node（装有 ceph-deploy）上装 ceph-base 的时候会出现问题，要运行如下命令
sudo dpkg -i --force-overwrite ceph-base_12.2.12-1xenial_amd64.deb
# 之后再回到 admin node 上执行
ceph-deploy install cloud08 cloud-XIII cloud04

# Deploy the initial monitor(s) and gather the keys
ceph-deploy mon create-initial
ceph-deploy --overwrite-conf mon create-initial
# 会出现问题：Unable to find /etc/ceph/ceph.client.admin.keyring on xxx
# Executing on each node
sudo ceph-create-keys --verbose --id xxx
# Gather keys
ceph-deploy gatherkeys xxx xxx xxx

# Use ceph-deploy to copy the configuration file and admin key to your admin node and your Ceph Nodes so that you can use the ceph CLI without having to specify the monitor address and ceph.client.admin.keyring each time you execute a command.
# ceph-deploy admin {ceph-node(s)}
ceph-deploy admin cloud08 cloud-XIII cloud04

# Deploy a manager daemon. (Required only for luminous+ builds)
# 可能会出现 ceph-deploy 无 mgr 功能的问题，此时需更新 ceph-deploy
ceph-deploy mgr create cloud08

# Add three OSDs
# 在每个节点上创建 part/lv/vg 来存储数据
# 参考链接：https://www.linuxidc.com/Linux/2016-06/132475.htm
# 参考链接：https://blog.csdn.net/u012291393/article/details/78636456
# 参考链接：https://blog.csdn.net/weixin_43228740/article/details/85340675
# ceph-deploy osd create --data {device} {ceph-node}
ceph-deploy osd create --data /dev/sdb1 cloud08
ceph-deploy osd create --data /dev/sda2 cloud-XIII
ceph-deploy osd create --data /dev/vg_data/lv_ceph cloud04

# Check your cluster’s health
ssh node1 sudo ceph health
ssh node1 sudo ceph -s

# To store object data in the Ceph Storage Cluster, a Ceph client must:
# 1. Set an object name
# 2. Specify a pool
# To find the object location: ceph osd map {poolname} {object-name}
# Exercise: Locate an Object
echo "This is a test." > testfile.txt
sudo ceph osd pool create mytest 8
# rados put {object-name} {file-path} --pool=mytest
sudo rados put test-object-1 testfile.txt --pool=mytest
sudo rados -p mytest ls
sudo ceph osd map mytest test-object-1
sudo rados rm test-object-1 --pool=mytest
sudo ceph osd pool rm mytest
# pool 不允许被删除时，需在 mon 节点的 /etc/ceph/ceph.conf 文件中添加以下内容
[mon] 
mon allow pool delete = true
# 接着重启 ceph-mon 服务
sudo systemctl restart ceph-mon.target
# 然后执行 pool 的删除命令
sudo ceph osd pool delete mytest mytest –yes-i-really-really-mean-it

# Purge the Ceph packages, and erase all its data and configuration
ceph-deploy purge {ceph-node} [{ceph-node}]
ceph-deploy purgedata {ceph-node} [{ceph-node}]
ceph-deploy forgetkeys
rm ceph.*



