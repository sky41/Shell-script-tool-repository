#!/bin/bash

# 定义备份根目录
BACKUP_ROOT="/opt/config_backups"

# 定义服务配置映射 (服务名:配置文件路径:服务系统名)
declare -A SERVICES
SERVICES["mysql"]="/etc/mysql/my.cnf:mysql"
SERVICES["redis"]="/etc/redis/redis.conf:redis"
SERVICES["nginx"]="/etc/nginx/nginx.conf:nginx"
SERVICES["postgresql"]="/etc/postgresql/main/postgresql.conf:postgresql"
SERVICES["apache"]="/etc/apache2/apache2.conf:apache2"
SERVICES["mongodb"]="/etc/mongodb.conf:mongodb"
SERVICES["elasticsearch"]="/etc/elasticsearch/elasticsearch.yml:elasticsearch"
SERVICES["rabbitmq"]="/etc/rabbitmq/rabbitmq.conf:rabbitmq-server"
SERVICES["zookeeper"]="/etc/zookeeper/conf/zoo.cfg:zookeeper"

# 1. 安全检查：必须是 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 错误：此脚本需要 root 权限运行，请使用 sudo 执行！"
    exit 1
fi

# 2. 备份函数
do_backup() {
    local service_name=$1
    local conf_path=$(echo ${SERVICES[$service_name]} | cut -d: -f1)
    
    if [ ! -f "$conf_path" ]; then
        echo "❌ 错误：找不到配置文件 $conf_path，请检查路径！"
        return 1
    fi

    # 创建该服务的专属备份目录
    local service_backup_dir="$BACKUP_ROOT/$service_name"
    mkdir -p "$service_backup_dir"
    
    # 生成带时间戳的备份文件名
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$service_backup_dir/$(basename $conf_path)_$timestamp"
    
    cp "$conf_path" "$backup_file"
    echo "✅ 备份成功！文件已保存至：$backup_file"
}

# 3. 回滚函数
do_restore() {
    local service_name=$1
    local conf_path=$(echo ${SERVICES[$service_name]} | cut -d: -f1)
    local service_sysname=$(echo ${SERVICES[$service_name]} | cut -d: -f2)
    local service_backup_dir="$BACKUP_ROOT/$service_name"

    # 检查是否有备份文件
    if [ ! -d "$service_backup_dir" ] || [ -z "$(ls -A $service_backup_dir)" ]; then
        echo "❌ 错误：该服务没有任何备份记录！"
        return 1
    fi

    echo "📂 可用的备份版本："
    local backups=($(ls -t "$service_backup_dir"))
    local i=1
    for file in "${backups[@]}"; do
        echo "[$i] $file"
        ((i++))
    done

    echo -n "请输入要回滚的备份序号 (输入 q 退出): "
    read choice
    if [ "$choice" == "q" ]; then exit 0; fi
    
    # 校验输入的序号
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo "❌ 输入无效！"
        return 1
    fi

    local selected_file="${backups[$((choice-1))]}"
    local full_path="$service_backup_dir/$selected_file"

    echo -n "⚠️  即将用 [$selected_file] 覆盖 [$conf_path] 并重启服务，确定继续吗？(y/n): "
    read confirm
    if [ "$confirm" != "y" ]; then
        echo "已取消回滚。"
        return 0
    fi

    # 执行覆盖与重启
    cp "$full_path" "$conf_path"
    echo "✅ 配置文件已还原。"
    
    echo "🔄 正在重启 $service_name 服务..."
    systemctl restart "$service_sysname"
    if [ $? -eq 0 ]; then
        echo "✅ $service_name 服务重启成功！回滚完成。"
    else
        echo "❌ $service_name 服务重启失败，请检查配置！"
    fi
}

# 4. 交互式主菜单
while true; do
    echo ""
    echo "========== 服务配置备份与回滚工具 =========="
    echo "请选择要操作的服务："
    echo "1) MySQL"
    echo "2) Redis"
    echo "3) Nginx"
    echo "4) PostgreSQL"
    echo "5) Apache"
    echo "6) MongoDB"
    echo "7) Elasticsearch"
    echo "8) RabbitMQ"
    echo "9) ZooKeeper"
    echo "q) 退出"
    echo "============================================"
    read -p "请输入选项: " main_choice

    case $main_choice in
        1) target_service="mysql" ;;
        2) target_service="redis" ;;
        3) target_service="nginx" ;;
        4) target_service="postgresql" ;;
        5) target_service="apache" ;;
        6) target_service="mongodb" ;;
        7) target_service="elasticsearch" ;;
        8) target_service="rabbitmq" ;;
        9) target_service="zookeeper" ;;
        q) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项！"; continue ;;
    esac

    echo ""
    echo "请选择对 [$target_service] 的操作："
    echo "1) 备份当前配置"
    echo "2) 回滚配置"
    echo "b) 返回上一级"
    read -p "请输入选项: " action_choice

    case $action_choice in
        1) do_backup "$target_service" ;;
        2) do_restore "$target_service" ;;
        b) continue ;;
        *) echo "无效选项！" ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
done