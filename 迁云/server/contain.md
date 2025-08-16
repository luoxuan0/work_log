## 20250813

### 容器化后释放闲置服务器

- 释放资源-国外
	- 列表
		- 除了 33.162 c-ind-87  的其他
	- 涉及位置（文档？）
		- 代码发布
			- c-ind-87上的ansible分组
				- 已经注释 /etc/ansible/hosts
		- 堡垒机 
			- 禁用（待删除）
		- 阿里云资源
			- 一台费用 1395.55/19=73.45/月/台
			- 37台 37*73.45=2717.65元/月

## 20250815

### 容器化后释放闲置服务器

- 释放资源-国内
	- 列表
		- 除了 194.116 c-ind-0-10-116  的其他
	- 涉及位置（文档？）
		- 代码发布
			- 服务器：sz-yunwei-jenkins 配置调整 /var/lib/jenkins/workspace/PROD--trackingmore/trackingmore_independent/targetServerIpListConf.sh
				- 已经注释
		- ansible调整
			- c-ind-0-10-116上的ansible分组
				- 已经注释 /etc/ansible/hosts
		- 堡垒机 
			- 禁用（待删除）
		- 阿里云资源
			- 一台费用 22.8+22.95=45.75/月/台
			- 79台 79*45.75=3614.25元/月

服务器：sz-yunwei-jenkins 配置调整 /var/lib/jenkins/workspace/PROD--trackingmore/trackingmore_independent/targetServerIpListConf.sh
```bash
# "172.16.30.17 /home/wwwroot/www.trackingmore.com 191 0 0 0 22"
# "172.16.30.19 /home/wwwroot/www.trackingmore.com 232 0 0 0 22"
# "172.16.30.20 /home/wwwroot/www.trackingmore.com 86 0 0 0 22"
# "172.16.30.23 /home/wwwroot/www.trackingmore.com 25 0 0 0 22"
# "172.16.30.26 /home/wwwroot/www.trackingmore.com 56 0 0 0 22"
# "172.16.30.27 /home/wwwroot/www.trackingmore.com 186 0 0 0 22"
# "172.16.30.29 /home/wwwroot/www.trackingmore.com 152 0 0 0 22"
# "172.16.30.31 /home/wwwroot/www.trackingmore.com 214 0 0 0 22"
# "172.16.30.37 /home/wwwroot/www.trackingmore.com 180 0 0 0 22"
"172.16.30.38 /home/wwwroot/www.trackingmore.com 116 0 0 0 22"
# "172.16.30.21 /home/wwwroot/www.trackingmore.com 31 0 0 0 22"
# "172.16.30.22 /home/wwwroot/www.trackingmore.com 155 0 0 0 22"
# "172.16.30.24 /home/wwwroot/www.trackingmore.com 149 0 0 0 22"
# "172.16.30.30 /home/wwwroot/www.trackingmore.com 1 0 0 0 22"
# "172.16.30.32 /home/wwwroot/www.trackingmore.com 135 0 0 0 22"
# "172.16.30.33 /home/wwwroot/www.trackingmore.com 39 0 0 0 22"
# "172.16.30.34 /home/wwwroot/www.trackingmore.com 77 0 0 0 22"
# "172.16.30.35 /home/wwwroot/www.trackingmore.com 126 0 0 0 22"
# "172.16.30.36 /home/wwwroot/www.trackingmore.com 130 0 0 0 22"
# "172.16.30.44 /home/wwwroot/www.trackingmore.com 205 0 0 0 22"
# "172.16.30.25 /home/wwwroot/www.trackingmore.com 29 0 0 0 22"
# "172.16.30.39 /home/wwwroot/www.trackingmore.com 251 0 0 0 22"
# "172.16.30.40 /home/wwwroot/www.trackingmore.com 179 0 0 0 22"
# "172.16.30.41 /home/wwwroot/www.trackingmore.com 142 0 0 0 22"
# "172.16.30.42 /home/wwwroot/www.trackingmore.com 236 0 0 0 22"
# "172.16.30.43 /home/wwwroot/www.trackingmore.com 250 0 0 0 22"
# "172.16.30.45 /home/wwwroot/www.trackingmore.com 129 0 0 0 22"
# "172.16.30.46 /home/wwwroot/www.trackingmore.com 219 0 0 0 22"
# "172.16.30.47 /home/wwwroot/www.trackingmore.com 233 0 0 0 22"
# "172.16.30.48 /home/wwwroot/www.trackingmore.com 166 0 0 0 22"
# "172.16.30.52 /home/wwwroot/www.trackingmore.com 249 0 0 0 22"
# "172.16.30.50 /home/wwwroot/www.trackingmore.com 186 0 0 0 22"
# "172.16.30.65 /home/wwwroot/www.trackingmore.com 157 0 0 0 22"
# "172.16.30.54 /home/wwwroot/www.trackingmore.com 36 0 0 0 22"
# "172.16.30.61 /home/wwwroot/www.trackingmore.com 36 0 0 0 22"
# "172.16.30.74 /home/wwwroot/www.trackingmore.com 178 0 0 0 22"
# "172.16.30.64 /home/wwwroot/www.trackingmore.com 210 0 0 0 22"
# "172.16.30.63 /home/wwwroot/www.trackingmore.com 232 0 0 0 22"
# "172.16.30.69 /home/wwwroot/www.trackingmore.com 182 0 0 0 22"
# "172.16.30.55 /home/wwwroot/www.trackingmore.com 189 0 0 0 22"
# "172.16.30.78 /home/wwwroot/www.trackingmore.com 221 0 0 0 22"
# "172.16.30.59 /home/wwwroot/www.trackingmore.com 133 0 0 0 22"
# "172.16.30.72 /home/wwwroot/www.trackingmore.com 229 0 0 0 22"
# "172.16.30.67 /home/wwwroot/www.trackingmore.com 28 0 0 0 22"
# "172.16.30.51 /home/wwwroot/www.trackingmore.com 14 0 0 0 22"
# "172.16.30.53 /home/wwwroot/www.trackingmore.com 191 0 0 0 22"
# "172.16.30.68 /home/wwwroot/www.trackingmore.com 132 0 0 0 22"
# "172.16.30.62 /home/wwwroot/www.trackingmore.com 248 0 0 0 22"
# "172.16.30.75 /home/wwwroot/www.trackingmore.com 79 0 0 0 22"
# "172.16.30.79 /home/wwwroot/www.trackingmore.com 20 0 0 0 22"
# "172.16.30.60 /home/wwwroot/www.trackingmore.com 242 0 0 0 22"
# "172.16.30.56 /home/wwwroot/www.trackingmore.com 92 0 0 0 22"
# "172.16.30.77 /home/wwwroot/www.trackingmore.com 129 0 0 0 22"
# "172.16.30.57 /home/wwwroot/www.trackingmore.com 134 0 0 0 22"
# "172.16.30.73 /home/wwwroot/www.trackingmore.com 174 0 0 0 22"
# "172.16.30.70 /home/wwwroot/www.trackingmore.com 7 0 0 0 22"
# "172.16.30.71 /home/wwwroot/www.trackingmore.com 135 0 0 0 22"
# "172.16.30.76 /home/wwwroot/www.trackingmore.com 221 0 0 0 22"
# "172.16.30.66 /home/wwwroot/www.trackingmore.com 79 0 0 0 22"
# "172.16.30.58 /home/wwwroot/www.trackingmore.com 22 0 0 0 22"
# "172.16.30.81 /home/wwwroot/www.trackingmore.com 216 0 0 0 22"
# "172.16.30.93 /home/wwwroot/www.trackingmore.com 7 0 0 0 22"
# "172.16.30.90 /home/wwwroot/www.trackingmore.com 251 0 0 0 22"
# "172.16.30.96 /home/wwwroot/www.trackingmore.com 39 0 0 0 22"
# "172.16.30.82 /home/wwwroot/www.trackingmore.com 135 0 0 0 22"
# "172.16.30.91 /home/wwwroot/www.trackingmore.com 221 0 0 0 22"
# "172.16.30.99 /home/wwwroot/www.trackingmore.com 103 0 0 0 22"
# "172.16.30.80 /home/wwwroot/www.trackingmore.com 127 0 0 0 22"
# "172.16.30.95 /home/wwwroot/www.trackingmore.com 129 0 0 0 22"
# "172.16.30.94 /home/wwwroot/www.trackingmore.com 133 0 0 0 22"
# "172.16.30.98 /home/wwwroot/www.trackingmore.com 194 0 0 0 22"
# "172.16.30.92 /home/wwwroot/www.trackingmore.com 85 0 0 0 22"
# "172.16.30.85 /home/wwwroot/www.trackingmore.com 209 0 0 0 22"
# "172.16.30.84 /home/wwwroot/www.trackingmore.com 52 0 0 0 22"
# "172.16.30.83 /home/wwwroot/www.trackingmore.com 137 0 0 0 22"
# "172.16.30.88 /home/wwwroot/www.trackingmore.com 235 0 0 0 22"
# "172.16.30.86 /home/wwwroot/www.trackingmore.com 97 0 0 0 22"
# "172.16.30.97 /home/wwwroot/www.trackingmore.com 236 0 0 0 22"
# "172.16.30.87 /home/wwwroot/www.trackingmore.com 180 0 0 0 22"
# "172.16.30.89 /home/wwwroot/www.trackingmore.com 203 0 0 0 22"
```