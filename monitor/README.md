[参考链接](https://www.jianshu.com/p/0dcdbc1135bd)

ceph_exporter.tar 为 exporter 的 docker 镜像

grafana-template/ 中存放的是 grafana dashboard 模版

#### 新增一个 exporter（如 cloud02）

    cp exporter-sed.yml exporter-cloud02.yml
    sed -i -e "s/--hostname--/cloud02/g" exporter-cloud02.yml
    kubectl apply -f exporter-cloud02.yml

#### 删除一个 exporter（如 cloud02）

    kubectl delete -f exporter-cloud02.yml