[参考链接](https://www.jianshu.com/p/750a8fde377b?tdsourcetag=s_pctim_aiomsg)

### external-storage-cephfs-provisioner.yaml

命名空间：

    namespace: kube-system

根据 label 选择节点：

    nodeSelector:
        ceph-osd: ceph-osd

PROVISIONER_NAME：

    env:
        - name: PROVISIONER_NAME
          value: ceph.com/cephfs

镜像有缓存（因过大未上传）

### storageclass-cephfs.yaml

注意更改：monitors

name：

    metadata:
        name: dynamic-cephfs

### cephfs-pvc-test.yaml

用作测试
