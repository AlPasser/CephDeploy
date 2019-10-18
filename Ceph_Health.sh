# Check your cluster’s health
ssh node1 sudo ceph health
ssh node1 sudo ceph health detail
ssh node1 sudo ceph -s

# HEALTH_WARN

# 1. application not enabled on 1 pool(s)
# sudo ceph osd pool application enable <pool-name> <app-name>
sudo ceph osd pool application enable kube rbd

# 2. crush map has straw_calc_version=0
# straw_calc_version: A value of 0 preserves the old, broken internal weight calculation; a value of 1 fixes the behavior.
# kernel version 在 4.5 以下时，straw_calc_version 要为 0，否则会出问题
# 使用推荐方法
sudo ceph osd crush tunables optimal

# 3. clock skew detected on mon
# 检查 mon node 的 ntp 是否开启

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

# HEALTH_ERR

# 1. OSD_SCRUB_ERRORS 1 scrub errors
# 数据的不一致导致的清理失败（scrub error）
# ceph 在存储的过程中，由于特殊原因，可能遇到对象信息大小和物理磁盘上实际大小不一致的情况，这会导致清理失败
# 查看出现问题的 pg 编号
sudo ceph health detail
# sudo ceph pg repair <pg_id>
# 如 pg 编号：1.6f
sudo ceph pg repair 1.6f

# 2. PG_DAMAGED Possible data damage: 1 pg inconsistent
# 会导致 scrub error，解决方法参照 HEALTH_ERR1

# 3. OBJECT_MISPLACED 3081/16294 objects misplaced (18.909%)
# 解决方法参照 HEALTH_ERR1