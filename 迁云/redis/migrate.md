## 20250808


搭建打通VPN后，有些情况（从阿里云访问gcp）需要添加路由
比如，redis，10.19.17.21，需要在 Cloud Router编辑vpn-router，Advertised routes选择Create custom routes，添加自定义的路由 10.19.17.0/24

## 20250925

[Redis Input/Output Tools (RIOT)](https://redis.github.io/riot/#_batching)

gcp redis价格
[Memorystore for Redis | Google Cloud](https://cloud.google.com/memorystore/docs/redis/pricing?e=48754805&hl=en#instance-pricing-with-no-read-replicas)