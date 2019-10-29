[参考链接](https://www.jianshu.com/p/0dcdbc1135bd)

### ceph_exporter.tar

存有 exporter docker 镜像

### grafana-template/

存放的是 grafana dashboard 模版

### 增删 exporter

    kubectl apply -f exporter.yml
    kubectl delete -f exporter.yml