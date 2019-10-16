### nginx.tar

存有 nginx:alpine docker 镜像

### Dockerfile

镜像构建文件

### 构建镜像（如版本 191016）

    docker build -t harbor.oceanai.com.cn/k8s_ceph/getpvcdata:191016 .

### 启动 Pod

    cp get-pvc-data-sed.yaml get-pvc-data-191016.yaml
    sed -i -e "s/--version--/191016/g" get-pvc-data-191016.yaml
    kubectl apply -f get-pvc-data-191016.yaml

### 删除 Pod

    kubectl delete -f get-pvc-data-191016.yaml