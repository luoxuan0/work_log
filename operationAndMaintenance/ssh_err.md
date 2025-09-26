# ssh远程异常

## 20250910

### ai咨询

```txt

帮忙看下，1，ssh异常，2，提供的信息是否包含敏感信息

ssh -vvv -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519.operation_from_145 gcp_35
OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017
debug1: Reading configuration data /root/.ssh/config
debug1: /root/.ssh/config line 1: Applying options for gcp_35
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: /etc/ssh/ssh_config line 58: Applying options for *
debug2: resolving "10.1.0.35" port 22
debug2: ssh_connect_direct: needpriv 0
debug1: Connecting to 10.1.0.35 [10.1.0.35] port 22.
debug1: Connection established.
debug1: permanently_set_uid: 0/0
debug1: identity file /root/.ssh/id_ed25519.operation_from_145 type 4
debug1: key_load_public: No such file or directory
debug1: identity file /root/.ssh/id_ed25519.operation_from_145-cert type -1
debug1: identity file /root/.ssh/id_ed25519.operation_from_145 type 4
debug1: key_load_public: No such file or directory
debug1: identity file /root/.ssh/id_ed25519.operation_from_145-cert type -1
debug1: Enabling compatibility mode for protocol 2.0
debug1: Local version string SSH-2.0-OpenSSH_7.4
debug1: Remote protocol version 2.0, remote software version OpenSSH_9.2p1 Debian-2+deb12u7
debug1: match: OpenSSH_9.2p1 Debian-2+deb12u7 pat OpenSSH* compat 0x04000000
debug2: fd 3 setting O_NONBLOCK
debug1: Authenticating to 10.1.0.35:22 as 'root'
debug3: hostkeys_foreach: reading file "/root/.ssh/known_hosts"
debug3: record_hostkey: found key type ECDSA in file /root/.ssh/known_hosts:40
debug3: load_hostkeys: loaded 1 keys from 10.1.0.35
debug3: order_hostkeyalgs: prefer hostkeyalgs: ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521
debug3: send packet: type 20
debug1: SSH2_MSG_KEXINIT sent
debug3: receive packet: type 20
debug1: SSH2_MSG_KEXINIT received
debug2: local client KEXINIT proposal
debug2: KEX algorithms: curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha256,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,ext-info-c
debug2: host key algorithms: ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-dss-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa,ssh-dss
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-cbc,aes192-cbc,aes256-cbc
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-cbc,aes192-cbc,aes256-cbc
debug2: MACs ctos: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: MACs stoc: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: compression ctos: none,zlib@openssh.com,zlib
debug2: compression stoc: none,zlib@openssh.com,zlib
debug2: languages ctos: 
debug2: languages stoc: 
debug2: first_kex_follows 0 
debug2: reserved 0 
debug2: peer server KEXINIT proposal
debug2: KEX algorithms: sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256,kex-strict-s-v00@openssh.com
debug2: host key algorithms: rsa-sha2-512,rsa-sha2-256,ecdsa-sha2-nistp256,ssh-ed25519
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
debug2: MACs ctos: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: MACs stoc: umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1
debug2: compression ctos: none,zlib@openssh.com
debug2: compression stoc: none,zlib@openssh.com
debug2: languages ctos: 
debug2: languages stoc: 
debug2: first_kex_follows 0 
debug2: reserved 0 
debug1: kex: algorithm: curve25519-sha256
debug1: kex: host key algorithm: ecdsa-sha2-nistp256
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: curve25519-sha256 need=64 dh_need=64
debug1: kex: curve25519-sha256 need=64 dh_need=64
debug3: send packet: type 30
debug1: expecting SSH2_MSG_KEX_ECDH_REPLY
debug3: receive packet: type 31
debug1: Server host key: ecdsa-sha2-nistp256 SHA256:xxx
debug3: hostkeys_foreach: reading file "/root/.ssh/known_hosts"
debug3: record_hostkey: found key type ECDSA in file /root/.ssh/known_hosts:40
debug3: load_hostkeys: loaded 1 keys from 10.1.0.35
debug1: Host '10.1.0.35' is known and matches the ECDSA host key.
debug1: Found key in /root/.ssh/known_hosts:40
debug3: send packet: type 21
debug2: set_newkeys: mode 1
debug1: rekey after 134217728 blocks
debug1: SSH2_MSG_NEWKEYS sent
debug1: expecting SSH2_MSG_NEWKEYS
debug3: receive packet: type 21
debug1: SSH2_MSG_NEWKEYS received
debug2: set_newkeys: mode 0
debug1: rekey after 134217728 blocks
debug2: key: /root/.ssh/id_ed25519.operation_from_145 (0x55f2f9d086f0), explicit
debug2: key: /root/.ssh/id_ed25519.operation_from_145 (0x55f2f9d0a1e0), explicit
debug3: send packet: type 5
debug3: receive packet: type 7
debug1: SSH2_MSG_EXT_INFO received
debug1: kex_input_ext_info: server-sig-algs=<ssh-ed25519,sk-ssh-ed25519@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ecdsa-sha2-nistp256@openssh.com,webauthn-sk-ecdsa-sha2-nistp256@openssh.com,ssh-dss,ssh-rsa,rsa-sha2-256,rsa-sha2-512>
debug1: kex_input_ext_info: publickey-hostbound@openssh.com=<0>
debug3: receive packet: type 6
debug2: service_accept: ssh-userauth
debug1: SSH2_MSG_SERVICE_ACCEPT received
debug3: send packet: type 50
debug3: receive packet: type 51
debug1: Authentications that can continue: publickey
debug3: start over, passed a different list publickey
debug3: preferred gssapi-keyex,gssapi-with-mic,publickey,keyboard-interactive,password
debug3: authmethod_lookup publickey
debug3: remaining preferred: keyboard-interactive,password
debug3: authmethod_is_enabled publickey
debug1: Next authentication method: publickey
debug1: Offering ED25519 public key: /root/.ssh/id_ed25519.operation_from_145
debug3: send_pubkey_test
debug3: send packet: type 50
debug2: we sent a publickey packet, wait for reply
debug3: receive packet: type 60
debug1: Server accepts key: pkalg ssh-ed25519 blen 51
debug2: input_userauth_pk_ok: fp SHA256:xxx
debug3: sign_and_send_pubkey: ED25519 SHA256:xxx
debug3: send packet: type 50
debug3: receive packet: type 51
debug1: Authentications that can continue: publickey
debug1: Offering ED25519 public key: /root/.ssh/id_ed25519.operation_from_145
debug3: send_pubkey_test
debug3: send packet: type 50
debug2: we sent a publickey packet, wait for reply
debug3: receive packet: type 51
debug1: Authentications that can continue: publickey
debug2: we did not send a packet, disable method
debug1: No more authentication methods to try.
Permission denied (publickey).

目标日志

# Ubuntu/Debian
tail -f /var/log/auth.log

# CentOS/RHEL
tail -f /var/log/secure

2025-09-10T02:22:59.354237+00:00 tm-redis-master sshd[1644136]: ROOT LOGIN REFUSED FROM 172.16.21.185 port 49568
2025-09-10T02:22:59.361018+00:00 tm-redis-master sshd[1644136]: ROOT LOGIN REFUSED FROM 172.16.21.185 port 49568 [preauth]
2025-09-10T02:22:59.364095+00:00 tm-redis-master sshd[1644136]: refusing previously-used ED25519 key [preauth]
2025-09-10T02:22:59.377101+00:00 tm-redis-master sshd[1644136]: Connection closed by authenticating user root 172.16.21.185 port 49568 [preauth]

```

下面先给结论，再给排查与修复步骤。

## 结论（针对你这次的日志）

1. **SSH 失败的直接原因**：目标机明确拒绝 root 登录
   目标机 `sshd` 日志里两条关键信息：

* `ROOT LOGIN REFUSED FROM 172.16.21.185 ...`
* `[preauth]`

这通常表示 **`PermitRootLogin` 被禁用**（或策略禁止 root 远程登录），因此即使你正确地提供了公钥，服务端在预认证阶段就拒绝了 root。你在客户端这边看到的流程是：

* 服务器先“测试接受”了公钥（`Server accepts key ... input_userauth_pk_ok`），
* 但真正签名认证时仍返回 `Authentications that can continue: publickey`，最后 `Permission denied (publickey)`。
  这和服务端的“拒绝 root 登录”是吻合的——**不是钥匙对不上，而是账号（root）被策略层面拒绝**。

2. **“refusing previously-used ED25519 key \[preauth]” 的含义**
   这行结合“ROOT LOGIN REFUSED”一起看，基本是 **sshd 在预认证阶段拒绝继续用同一把 key 重试** 的提示；根因仍是 root 登录被策略拒绝，而不是 key 坏了。

---

## 该怎么修（两种思路）

### A. 允许 root 用密钥登录（若你的安全基线允许）

在目标机上检查并调整 `sshd_config`：

```bash
# 查看当前生效配置（最准确）
sshd -T | egrep 'permitrootlogin|pubkeyauthentication|authorizedkeysfile|authenticationmethods'

# 打开配置文件（Debian/Ubuntu 系）
sudo vi /etc/ssh/sshd_config

# 确保如下（至少）：
PermitRootLogin prohibit-password   # 仅允许密钥登录；如需临时放开可用 yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
# 如果你配置了 AuthenticationMethods，确保包含 publickey，比如：
# AuthenticationMethods publickey
```

保存后重载：

```bash
sudo systemctl reload sshd
# 或
sudo systemctl restart ssh
```

再核对 root 的公钥文件是否到位、权限是否正确：

```bash
sudo ls -l /root/.ssh/authorized_keys
sudo stat /root /root/.ssh /root/.ssh/authorized_keys

# 权限建议
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

确认 **authorized\_keys** 里 **公钥内容** 与你本机私钥配对：

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.operation_from_145.pub     # 本机查看指纹
# 在服务端用相同命令查看 authorized_keys 里对应行的指纹是否一致
```

> 若 authorized\_keys 使用了 `from="..."`、`expiry-time="..."`、`command="..."` 等限制项，确认你的来源 IP（这次是 172.16.21.185）匹配，且未过期、无强约束冲突。

### B. 不允许 root 登陆，改用普通用户 + sudo（更安全、也常见）

* 在目标机创建或确认一个允许 SSH 的普通用户（比如 `ops`），把你的公钥放进 `/home/ops/.ssh/authorized_keys`，权限同上。
* `sshd_config` 保持 `PermitRootLogin no`（或 `prohibit-password`），并设置 `AllowUsers ops`（可选）。
* 用 `ssh -i ~/.ssh/id_ed25519.operation_from_145 ops@10.1.0.35` 登陆，再用 `sudo -i` 切到 root。

---

## 快速自检清单（逐条对照）

* [ ] 服务端 `sshd -T | grep permitrootlogin` 显示的状态是否为 `no`？（是的话，root 就会被拒）
* [ ] `PubkeyAuthentication yes` 是否生效？
* [ ] `AuthorizedKeysFile` 路径是否默认或被改动？（如果改动，确认文件实际存放位置一致）
* [ ] `AuthenticationMethods` 是否把 `publickey` 排除掉或设置成了多因子而未满足？
* [ ] `/root/.ssh` 与 `authorized_keys` 权限是否为 700 / 600？
* [ ] `authorized_keys` 中该 key 行是否包含 `from="..."` 等限制，且与你来源 IP（172.16.21.185）匹配？
* [ ] 客户端是否明确指定了正确的私钥（你已用 `-o IdentitiesOnly=yes -i ...`，这点 OK）
* [ ] 若有跳板机/NAT，服务端看到的来源 IP 是否在白名单或匹配 `from=` 条件？

---

## 你贴出的信息是否包含敏感内容？

**有一定敏感性**，建议对外分享前做脱敏处理：

* **内部网段/主机信息**：`10.1.0.35`、`172.16.21.185`、主机名 `tm-redis-master`（属于内部拓扑与资产信息）。
* **账户名**：`root`（暴露管理口令/策略面）。
* **密钥文件名**：`id_ed25519.operation_from_145`（可推断密钥用途与命名规范）。
* **SSH 版本信息**：客户端 `OpenSSH_7.4p1`（较老，可能诱发针对性探测）、服务端 `OpenSSH_9.2p1`。
* **已知主机条目位置**：`known_hosts:40`（影响较小，但也属环境细节）。
* **公钥指纹被你用 xxx 遮挡了**（做得对，继续保持）。

> 对外共享建议：隐藏/模糊处理内网 IP、主机名、用户名、文件路径、版本号与任何能够映射到你环境结构的细节。

---

## 额外建议（安全与稳定）

* **升级客户端 OpenSSH**（你是 7.4，年份很久远）：新版本对算法与兼容性更好，也能避免一些老版本 bug/弱算法协商。
* **为 root 登录设“临时开关”**：若确需 root 直登，仅在必要窗口内设为 `prohibit-password` 并配合 `AllowUsers`、IP 白名单与 `Match Address` 精细化限制，完成后再关闭。
* **启用双因子（可选）**：通过 `AuthenticationMethods publickey,keyboard-interactive` 配合 PAM OTP，提升敏感资产安全性（注意同时检查自动化任务影响）。

如果你愿意，我可以按你的当前策略（允许/禁止 root 直登）给一份**可回退的变更脚本**（含备份、验证与回滚步骤）。


```bash

# 目标服务器上执行
sshd -T | egrep 'permitrootlogin|pubkeyauthentication|authorizedkeysfile|authenticationmethods'
# 确认原因为root禁用登录
permitrootlogin no
pubkeyauthentication yes
authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys2
authenticationmethods any

```