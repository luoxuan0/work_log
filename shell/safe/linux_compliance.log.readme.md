服务器
sz-dolphinscheduler-140-175
目录
/home/ansible/security
```bash

# 执行脚本版本
linux_compliance_1.sh

ansible-playbook -l test run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./test.sh",
       "script_dest": "/tmp/test.sh",
       "script_args": ["--preview","prod","--force"],
       "creates": "/var/run/test.done",
       "cleanup_after": true}'

ansible-playbook -l test run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./test.sh",
       "script_dest": "/tmp/test.sh",
       "script_args": ["--preview","prod","--force"],
       "creates": "/var/run/test.done",
       "cleanup_after": false}'


# 保存历史记录
ansible-playbook -l all_51 run-script.yml   -e '{"use_shell": false,
       "script_src": "./test.sh",
       "script_dest": "/tmp/test.sh",
       "script_args": ["--preview","prod","--force"],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> save_history.log

# 执行前查看修改，不落盘
ansible-playbook -l all_51 run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./linux_compliance.sh",
       "script_dest": "/tmp/linux_compliance.sh",
       "script_args": ["--preview","",""],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> linux_compliance.sh.preview.log

# 执行前查看依赖
ansible-playbook -l all_51 run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./linux_compliance.sh",
       "script_dest": "/tmp/linux_compliance.sh",
       "script_args": ["--check-deps","",""],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> linux_compliance.sh.check.deps.log

# 对缺失依赖的服务器，进行依赖安装
ansible-playbook -l all_no_deps_51 run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./linux_compliance.sh",
       "script_dest": "/tmp/linux_compliance.sh",
       "script_args": ["--install-deps","",""],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> linux_compliance.sh.install.deps.log

# 对缺失依赖的服务器，进行依赖安装检查
ansible-playbook -l all_no_deps_51 run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./linux_compliance.sh",
       "script_dest": "/tmp/linux_compliance.sh",
       "script_args": ["--check-deps","",""],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> linux_compliance.sh.check.deps.log

# # 回滚依赖安装
# ansible-playbook -l all_51 run-script.yml \
#   -e '{"use_shell": false,
#        "script_src": "./linux_compliance.sh",
#        "script_dest": "/tmp/linux_compliance.sh",
#        "script_args": ["--rollback-deps","",""],
#        "creates": "/var/run/test.done",
#        "cleanup_after": false}' >> linux_compliance.sh.rollback.deps.log

# 执行合规整改
ansible-playbook -l all_51 run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./linux_compliance.sh",
       "script_dest": "/tmp/linux_compliance.sh",
       "script_args": ["--apply","",""],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> linux_compliance.sh.apply.log

# 检查合规整改结果
ansible-playbook -l all_51 run-script.yml \
  -e '{"use_shell": false,
       "script_src": "./linux_compliance.sh",
       "script_dest": "/tmp/linux_compliance.sh",
       "script_args": ["--verify","",""],
       "creates": "/var/run/test.done",
       "cleanup_after": false}' >> linux_compliance.sh.verify.log

```