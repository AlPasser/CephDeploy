[参考链接](https://www.jianshu.com/p/0dcdbc1135bd)

### ceph_exporter.tar

存有 exporter docker 镜像

### grafana-template/

存放的是 grafana dashboard 模版

### 新增一个 exporter（如 cloud02）

    cp exporter-sed.yml exporter-cloud02.yml
    sed -i -e "s/--hostname--/cloud02/g" exporter-cloud02.yml
    kubectl apply -f exporter-cloud02.yml

镜像有缓存（因过大未上传）

### 删除一个 exporter（如 cloud02）

    kubectl delete -f exporter-cloud02.yml