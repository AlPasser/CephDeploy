# 以下操作都是在 UBUNTU 16.04 上进行的

# 增加 monitor
# At least three monitors are normally required for redundancy and high availability.
# ceph-deploy mon add {ceph-nodes}
ceph-deploy mon add cloud04 cloud-XIII
# 可能会有问题：admin_socket: exception getting command descriptions: [Errno 2] No such file or directory
# 这是由 ceph.conf 中缺少 public network 配置导致的
# 在 admin node 上的 ceph.conf 中添加
public network = 192.168.1.0/24
# 将修改后的 ceph.conf 推送到各个节点
ceph-deploy --overwrite-conf config push cloud08 cloud04 cloud-XIII
# 如果出现 mon add 成功但一直无法加入 quorum 的情形（由人工误操作或历史数据未清理导致），那么要先移除那个节点(清理数据),最后再把该节点加进集群。

# Once you have added your new Ceph Monitors, Ceph will begin synchronizing the monitors and form a quorum.
# Check the quorum status
sudo ceph quorum_status --format json-pretty

# 增加 manager
# At least two managers are normally required for high availability.
ceph-deploy mgr create cloud-XIII

# 增加 OSD
# At least 3 Ceph OSDs are normally required for redundancy and high availability.
# 见 Ceph Storage Cluster Quick Start.sh






