[参考链接](https://www.jianshu.com/p/750a8fde377b?tdsourcetag=s_pctim_aiomsg)

#### external-storage-rbd-provisioner.yaml

命名空间：

    namespace: kube-system

根据 label 选择节点：

    nodeSelector:
        ceph-osd: ceph-osd

PROVISIONER_NAME：

    env:
        - name: PROVISIONER_NAME
          value: ceph.com/rbd

#### storageclass-ceph-rbd.yaml

注意更改：monitors

name：

    metadata:
        name: dynamic-ceph-rbd

#### ceph-rbd-pvc-test.yaml

用作测试

注意：其所在的 namespace（这里为 default）下应当有 ceph-user-secret
