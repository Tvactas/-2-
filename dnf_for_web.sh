#!/bin/bash

# -------------------------------------------------------------------------
# 脚本名称: setup_web_server_centos8.sh
# 版本: v1.0
# 更新日期: 2024-12-10
# 适用系统: CentOS 8, RHEL 8, CentOS Stream, RHEL 8+
# 功能描述:
#   - 自动更新系统并安装所需软件包
#   - 安装和配置 nginx 作为 Web 服务器
#   - 配置防火墙并允许 HTTP/HTTPS 服务通过
#   - 创建用户并设置密码
#   - 获取并安装 SSL 证书
#   - 更新 nginx 配置文件并重启服务
# -------------------------------------------------------------------------

# 运行命令并输出状态
run_command() {
    local description=$1
    shift
    echo "正在${description}..."
    "$@" || { echo "${description}失败！请检查错误信息。"; exit 1; }
}

# 检查软件包是否已安装
package_installed() {
    dnf list installed "$1" &>/dev/null
}

# 更新系统
update_system() {
    run_command "更新系统" sudo dnf update -y
}

# 安装指定的软件包
install_package() {
    local package=$1
    if ! package_installed "$package"; then
        run_command "安装 ${package}" sudo dnf install -y "$package"
    else
        echo "${package} 已经安装，跳过安装。"
    fi
}

# 启动并设置服务开机自启
start_service() {
    local service=$1
    run_command "启动 ${service} 服务" sudo systemctl start "$service"
    run_command "设置 ${service} 服务为开机自启" sudo systemctl enable "$service"
    run_command "检查 ${service} 服务状态" sudo systemctl status "$service"
}

# 配置防火墙
configure_firewall() {
    local service=$1
    run_command "允许防火墙通过 ${service}" sudo firewall-cmd --permanent --add-service="$service"
}

# 创建用户并设置密码
create_user() {
    local user=$1

    if id "$user" &>/dev/null; then
        echo "用户 ${user} 已经存在，跳过创建。"
    else
        run_command "创建用户 ${user}" sudo useradd "$user"
        echo "请输入用户 ${user} 的密码："
        run_command "设置用户 ${user} 密码" sudo passwd "$user"
    fi
}

# 更新 nginx.conf 文件
update_nginx_conf() {
    local nginx_conf="/etc/nginx/nginx.conf"
    local insert_file="/root/insert.txt"

    if [[ ! -f "$insert_file" ]]; then
        echo "insert.txt 文件不存在，请确保文件路径正确！"
        exit 1
    fi

    if [[ ! -f "$nginx_conf" ]]; then
        echo "nginx.conf 文件不存在，请确保路径正确！"
        exit 1
    fi

    run_command "清空 nginx.conf 文件" truncate -s 0 "$nginx_conf"
    run_command "更新 nginx.conf 文件内容" bash -c "cat '$insert_file' > '$nginx_conf'"
}

# 主程序
main() {
    if [[ $EUID -ne 0 ]]; then
        echo "此脚本需要root权限，请使用 sudo 运行"
        exit 1
    fi

    update_system
    install_package "epel-release"
    install_package "nginx"
    start_service "nginx"
    systemctl stop nginx
    start_service "firewalld"
    configure_firewall "http"
    configure_firewall "https"
    run_command "重新加载防火墙" sudo firewall-cmd --reload
    create_user "tvacats"
    sudo dnf clean all
    install_package "certbot"

    echo "请通过 FTP 工具（例如 xftp）将打包后的 dist 文件上传到 /home/tvacats/web_for_usr/dist 目录。"
    echo "获取 SSL 证书的命令："
    echo "sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com"

    update_nginx_conf

    echo "脚本执行完毕。"
}

main

