# 参考链接：https://www.jianshu.com/p/750a8fde377b?tdsourcetag=s_pctim_aiomsg
# 以下操作都是在 UBUNTU 16.04 上进行的

# 环境：
# 1、已部署好 k8s v1.15.4
# 2、已部署好 ceph minic 集群

# 使用 ceph rbd

# rbd-provisioner
cat >external-storage-rbd-provisioner.yaml<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbd-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-provisioner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services"]
    resourceNames: ["kube-dns"]
    verbs: ["list", "get"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-provisioner
subjects:
  - kind: ServiceAccount
    name: rbd-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: rbd-provisioner
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: rbd-provisioner
  namespace: kube-system
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rbd-provisioner
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rbd-provisioner
subjects:
- kind: ServiceAccount
  name: rbd-provisioner
  namespace: kube-system

---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: rbd-provisioner
  namespace: kube-system
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: rbd-provisioner
    spec:
      containers:
      - name: rbd-provisioner
        # image: "quay.io/external_storage/rbd-provisioner:v2.0.0-k8s1.11"
        image: "harbor.oceanai.com.cn/k8s_ceph/rbd-provisioner:v2.1.1-k8s1.11"
        env:
        - name: PROVISIONER_NAME
          value: ceph.com/rbd
      serviceAccount: rbd-provisioner
      nodeSelector:
        ceph-osd: ceph-osd
EOF
# 以上 docker 镜像 save 在 rbd-provisioner.tar 中
# rbd-provisioner 暂时先只放在 lable "ceph-osd: ceph-osd" 的机子上（ceph node，装有 osd），还未测试放其他节点上是否会有问题（更新：理论推断是会有问题的）
kubectl apply -f external-storage-rbd-provisioner.yaml
kubectl get pod -n kube-system

# 配置 sc
# 在 k8s 集群的所有节点上安装 ceph-common（所需的 deb 文件都在 needed_deb_minic 文件夹中）
# 创建 osd pool，在 ceph 的 mon 或者 admin 节点上运行
# pg 的设置参照公式：Total PGs = ((Total_number_of_OSD * 100) / max_replication_count) / pool_count
# 取靠近结算结果的 2 的 N 次方的值。比如总共 OSD 数量是 2，复制份数 3 ，pool 数量是 1，那么按上述公式计算出的结果是 66.66，取跟它接近的 2 的 N 次方是 64，那么每个 pool 分配的 PG 数量就是 64。
sudo ceph osd pool create kube 64
sudo ceph osd pool ls
# 创建 k8s 访问 ceph 的用户，在 ceph 的 mon 或者 admin 节点上运行
sudo ceph auth get-or-create client.kube mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=kube' -o ceph.client.kube.keyring
# 查看 key，在 ceph 的 mon 或者 admin 节点上运行
sudo ceph auth get-key client.admin
sudo ceph auth get-key client.kube
# 创建 admin secret
# CEPH_ADMIN_SECRET 替换为 client.admin 获取到的key
export CEPH_ADMIN_SECRET='AQBBAnRbSiSOFxAAEZXNMzYV6hsceccYLhzdWw=='
kubectl create secret generic ceph-secret --type="kubernetes.io/rbd" \
--from-literal=key=$CEPH_ADMIN_SECRET \
--namespace=kube-system
# 在 default 命名空间创建 pvc 用于访问 ceph 的 secret
# CEPH_KUBE_SECRET 替换为 client.kube 获取到的 key
export CEPH_KUBE_SECRET='AQBZK3VbTN/QOBAAIYi6CRLQcVevW5HM8lunOg=='
kubectl create secret generic ceph-user-secret --type="kubernetes.io/rbd" \
--from-literal=key=$CEPH_KUBE_SECRET \
--namespace=default
# 查看 secret
kubectl get secret ceph-user-secret -o yaml
kubectl get secret ceph-secret -n kube-system -o yaml
# sc
cat >storageclass-ceph-rbd.yaml<<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: dynamic-ceph-rbd
provisioner: ceph.com/rbd
# provisioner: kubernetes.io/rbd
parameters:
  monitors: 192.168.1.8:6789
  adminId: admin
  adminSecretName: ceph-secret
  adminSecretNamespace: kube-system
  pool: kube
  userId: kube
  userSecretName: ceph-user-secret
  fsType: ext4
  imageFormat: "2"
  imageFeatures: "layering"
EOF
kubectl apply -f storageclass-ceph-rbd.yaml
kubectl get sc

# 测试使用
# pvc
cat >ceph-rbd-pvc-test.yaml<<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ceph-rbd-claim
spec:
  accessModes:     
    - ReadWriteOnce
  storageClassName: dynamic-ceph-rbd
  resources:
    requests:
      storage: 2Gi
EOF
kubectl apply -f ceph-rbd-pvc-test.yaml
kubectl get pvc
kubectl get pv
# nginx pod 挂载测试
cat >nginx-pod.yaml<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod1
  labels:
    name: nginx-pod1
spec:
  containers:
  - name: nginx-pod1
    image: nginx:alpine
    ports:
    - name: web
      containerPort: 80
    volumeMounts:
    - name: ceph-rbd
      mountPath: /usr/share/nginx/html
  volumes:
  - name: ceph-rbd
    persistentVolumeClaim:
      claimName: ceph-rbd-claim
  nodeSelector:
    ceph-osd: ceph-osd
EOF
# 暂时先只放在 lable "ceph-osd: ceph-osd" 的机子上（ceph node，装有 osd），还未测试放其他节点上是否会有问题（更新：已测，在其他节点上也无问题）
kubectl apply -f nginx-pod.yaml
kubectl get pods -o wide
kubectl exec -ti nginx-pod1 -- /bin/sh -c 'echo Hello World from Ceph RBD!!! > /usr/share/nginx/html/index.html'
POD_ID=$(kubectl get pods -o wide | grep nginx-pod1 | awk '{print $(6)}')
curl http://$POD_ID
kubectl delete -f nginx-pod.yaml
kubectl delete -f ceph-rbd-pvc-test.yaml
# 注意：kubectl delete -f ceph-rbd-pvc-test.yaml 会删除数据

# 问题解决
# 1、-1 auth: unable to find a keyring on /etc/ceph/ceph.client.kube.keyring,/etc/ceph/ceph.keyring,/etc/ceph/keyring,/etc/ceph/keyring.bin,: (2) No such file or directory
# 这是没找到秘钥，需要将 ceph.client.kube.keyring 文件复制到 rbd-provisioner 所在机器的 /etc/ceph/ 目录下
# 尽管已经创建了 k8s secret 但还是要这样做，这很奇怪，网上有些人说不用，但没怎么看懂，留给以后研究
# 在链接 https://itzg.github.io/2018/05/24/setting-up-kubernetes-on-a-budget-with-ceph-volumes.html 中表示需要这么做
ssh xxx sudo ceph auth get client.kube -o /etc/ceph/ceph.client.kube.keyring
# 2、rbd: map failed exit status 110, ...
# 在 ceph 的 admin node 上执行
sudo ceph osd crush tunables legacy
sudo ceph osd crush reweight-all
# 也可以将 kernel 升级到 4.5 以上来解决此问题

# 以上的 k8s ceph rbd 所持久化的数据目前只能在 k8s Pod 中查看，查看方法见 get_pvc_data 文件夹

# 使用 ceph fs
# linux 内核需要 4.10+，否则会出现无法正常使用的问题

# 以下操作在 ceph 的 mon 或者 admin 节点上进行
# CephFS 需要使用两个 Pool 来分别存储数据和元数据
sudo ceph osd pool create fs_data 128
sudo ceph osd pool create fs_metadata 128
sudo ceph osd lspools
# 创建一个 CephFS
sudo ceph fs new cephfs fs_metadata fs_data
# 查看
sudo ceph fs ls

# cephfs-provisioner
cat >external-storage-cephfs-provisioner.yaml<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cephfs-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cephfs-provisioner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cephfs-provisioner
subjects:
  - kind: ServiceAccount
    name: cephfs-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cephfs-provisioner
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cephfs-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cephfs-provisioner
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cephfs-provisioner
subjects:
- kind: ServiceAccount
  name: cephfs-provisioner
  namespace: kube-system

---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: cephfs-provisioner
  namespace: kube-system
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: cephfs-provisioner
    spec:
      containers:
      - name: cephfs-provisioner
        image: "quay.io/external_storage/cephfs-provisioner:v2.0.0-k8s1.11"
        env:
        - name: PROVISIONER_NAME
          value: ceph.com/cephfs
        command:
        - "/usr/local/bin/cephfs-provisioner"
        args:
        - "-id=cephfs-provisioner-1"
      serviceAccount: cephfs-provisioner
      nodeSelector:
        ceph-osd: ceph-osd
EOF
kubectl apply -f external-storage-cephfs-provisioner.yaml
kubectl get pod -n kube-system

# sc
# 在 ceph 的 mon 或 admin 节点上查看 key
ceph auth get-key client.admin
# 创建 admin secret
# CEPH_ADMIN_SECRET 替换为 client.admin 获取到的 key
export CEPH_ADMIN_SECRET='AQBBAnRbSiSOFxAAEZXNMzYV6hsceccYLhzdWw=='
kubectl create secret generic ceph-secret --type="kubernetes.io/rbd" \
--from-literal=key=$CEPH_ADMIN_SECRET \
--namespace=kube-system
# 查看 secret
kubectl get secret ceph-secret -n kube-system -o yaml
# 配置 sc
cat >storageclass-cephfs.yaml<<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: dynamic-cephfs
provisioner: ceph.com/cephfs
parameters:
    monitors: 11.11.11.111:6789,11.11.11.112:6789,11.11.11.113:6789
    adminId: admin
    adminSecretName: ceph-secret
    adminSecretNamespace: "kube-system"
    claimRoot: /volumes/kubernetes
EOF
kubectl apply -f storageclass-cephfs.yaml
kubectl get sc

# 测试使用
# pvc
cat >cephfs-pvc-test.yaml<<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cephfs-claim
spec:
  accessModes:     
    - ReadWriteOnce
  storageClassName: dynamic-cephfs
  resources:
    requests:
      storage: 2Gi
EOF
kubectl apply -f cephfs-pvc-test.yaml
kubectl get pvc
kubectl get pv
# nginx pod
cat >nginx-pod.yaml<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod1
  labels:
    name: nginx-pod1
spec:
  containers:
  - name: nginx-pod1
    image: nginx:alpine
    ports:
    - name: web
      containerPort: 80
    volumeMounts:
    - name: cephfs
      mountPath: /usr/share/nginx/html
  volumes:
  - name: cephfs
    persistentVolumeClaim:
      claimName: cephfs-claim
EOF
kubectl apply -f nginx-pod.yaml
kubectl get pods -o wide
# 修改文件内容
kubectl exec -ti nginx-pod1 -- /bin/sh -c 'echo Hello World from CephFS!!! > /usr/share/nginx/html/index.html'
# 访问测试
POD_ID=$(kubectl get pods -o wide | grep nginx-pod1 | awk '{print $(6)}')
curl http://$POD_ID
# 清理
kubectl delete -f nginx-pod.yaml
kubectl delete -f cephfs-pvc-test.yaml

# ceph fs 挂载
# 使用 ceph-fuse 挂载
# sudo ceph-fuse -m mon-ip-addr:mon-port mount-dir
sudo ceph-fuse -m 192.168.1.8:6789 fsmount



