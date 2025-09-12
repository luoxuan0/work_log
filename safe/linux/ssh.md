```bash
# 从ssh配置
AllowUsers cxj@192.168.45.14
PasswordAuthentication no
PubkeyAuthentication yes

45.14上还是可通过密码

# 允许指定IP
iptables -A INPUT -p tcp -s 192.168.45.14 --dport 22 -j ACCEPT
# 拒绝其他
iptables -A INPUT -p tcp --dport 22 -j DROP


# 排查
# 找出所有相关配置的位置
grep -R "PasswordAuthentication\|KbdInteractiveAuthentication\|ChallengeResponseAuthentication\|AuthenticationMethods\|AllowUsers"   /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
/etc/ssh/sshd_config:#PasswordAuthentication yes
#PasswordAuthentication yes
/etc/ssh/sshd_config:ChallengeResponseAuthentication no
/etc/ssh/sshd_config:# be allowed through the ChallengeResponseAuthentication and
/etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
/etc/ssh/sshd_config:# PAM authentication via ChallengeResponseAuthentication may bypass
/etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication
/etc/ssh/sshd_config:# and ChallengeResponseAuthentication to 'no'.
/etc/ssh/sshd_config:AllowUsers cxj
/etc/ssh/sshd_config:PasswordAuthentication no
/etc/ssh/sshd_config.d/50-cloud-init.conf:PasswordAuthentication yes

# 看“生效后的最终配置”
sshd -T | egrep 'passwordauthentication|kbdinteractiveauthentication|challenge|usepam|authenticationmethods|pubkeyauthentication|allowusers'
usepam yes
pubkeyauthentication yes
passwordauthentication yes
kbdinteractiveauthentication no
challengeresponseauthentication no
allowusers cxj
authenticationmethods any

# 将这里的注释 /etc/ssh/sshd_config.d/50-cloud-init.conf:PasswordAuthentication yes

# 实现了 仅允许指定用户通过密钥登录 不允许密码登录


# 一般 include 的目录下文件按字母顺序加载，例如：

/etc/ssh/sshd_config.d/00-xxx.conf
/etc/ssh/sshd_config.d/50-cloud-init.conf
/etc/ssh/sshd_config.d/99-final.conf

# 那么 99-final.conf 会覆盖前面所有。

#  建 99-hardening.conf，放置你想强制的配置
# sshd -t 语法检查

```