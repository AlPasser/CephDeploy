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
# 在每个节点上创建 part/vg/lv 来存储数据
# 参考链接：https://www.linuxidc.com/Linux/2016-06/132475.htm
# 参考链接：https://blog.csdn.net/u012291393/article/details/78636456
# 参考链接：https://blog.csdn.net/weixin_43228740/article/details/85340675
# 注意：若为了 umount 而删除了 /etc/fstab 中的某行，那么最后需要手动加回去，否则无法开机自动 mount。
# /etc/fstab 中的一行如下
/dev/vg_data/lv_data    /data    ext4    defaults    0    0
# ceph-deploy osd create --data {device} {ceph-node}
ceph-deploy osd create --data /dev/sdb1 cloud08
ceph-deploy osd create --data /dev/sda2 cloud-XIII
ceph-deploy osd create --data /dev/vg_data/lv_ceph cloud04
# 如果某个 osd 无法创建（Unable to create a new OSD id），那么要先移除那个节点(清理数据),最后再把该节点加进集群。

# Check your cluster’s health
ssh node1 sudo ceph health
ssh node1 sudo ceph health detail
ssh node1 sudo ceph -s
# 以下为 HEALTH_WARN 警告
# 1. application not enabled on 1 pool(s)
# sudo ceph osd pool application enable <pool-name> <app-name>
sudo ceph osd pool application enable kube rbd
# 2. crush map has straw_calc_version=0
# straw_calc_version: A value of 0 preserves the old, broken internal weight calculation; a value of 1 fixes the behavior.
# kernel version 在 4.5 以下时，straw_calc_version 要为 0，否则会出问题
# 3. mon cloudxxx is low on available space
# 目录 / 下的空间不足
# 先 destroy mon，再 add mon（该方法无用）
ceph-deploy mon destroy cloudxxx
ceph-deploy mon add cloudxxx
# mon add 的时候可能会卡住，且此时 sudo ceph -s 也会卡住（0 monclient(hunting): authenticate timed out after 300）
# 原因可能是没配 ceph.conf 中的 mon_host，mon_host 要写上所有的 mon，如
mon_host = 192.168.1.8,192.168.1.13,192.168.1.4
# 然后再将修改后的 ceph.conf 推送到各个节点
ceph-deploy --overwrite-conf config push cloud08 cloud04 cloud-XIII

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
# 先删 osd
# 使用 part 的话需要先删掉 ceph vg，再：sudo bash -c "rm /etc/lvm/archive/ceph*"
# 使用 lv 的话需要先删掉原有 lv 然后再创建它，否则下次加不进 osd
ceph-deploy purge {ceph-node} [{ceph-node}]
ceph-deploy purgedata {ceph-node} [{ceph-node}]
ceph-deploy forgetkeys
rm ceph.*
# 手动深度删除该节点上的相关文件与目录
# 查找相关文件：
sudo bash -c "find / -name '*ceph*'"
# 删除如：
sudo bash -c "rm /etc/systemd/system/*ceph* -rf"
sudo bash -c "rm /var/lib/systemd/deb-systemd-helper-enabled/*ceph* -rf"




