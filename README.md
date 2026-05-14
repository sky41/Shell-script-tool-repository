#### Shell Script Tool Repository
A collection of practical and efficient shell scripts designed to automate daily DevOps and system administration tasks. Currently featuring a robust **Service Configuration Backup & Rollback Tool**.

####  Features
* **Automated Configuration Backup:** Easily back up critical service configuration files (MySQL, Redis, etc.) with automatic timestamping to prevent data loss.
* **One-Click Rollback:** Quickly restore previous configuration versions if a service fails due to misconfiguration.
* **Interactive CLI Menu:** User-friendly command-line interface to select services and actions without memorizing complex commands.
* **Safety First:** Includes root privilege checks and confirmation prompts to prevent accidental operations.
* **Extensible Architecture:** Simple dictionary-based structure makes it easy to add support for new services (e.g., Nginx, PostgreSQL).

#### ️ Prerequisites
* A Linux-based operating system (Ubuntu, CentOS, Debian, etc.)
* `bash` shell
* `sudo` privileges (required for modifying system files and restarting services)

####  Installation & Usage
1. **Clone the repository:**
```bash
git clone https://github.com/sky41/Shell-Script-Tool-Repository.git
cd Shell-Script-Tool-Repository
```

2. **Grant execution permissions:**
```bash
chmod +x config_manager.sh
```

3. **Run the script with root privileges:**
```bash
sudo ./config_manager.sh
```

4. **Follow the interactive menu:**
* Select the target service (e.g., MySQL, Redis).
* Choose an action: **Backup** current config or **Restore** a previous version.

####  Project Structure
```
.
├── config_manager.sh   # Main script for backup and rollback operations
└── README.md           # Project documentation
```

#### ️ Configuration
To add support for additional services, simply edit the `SERVICES` associative array in `config_manager.sh`:
```bash
# Format: ["service_alias"]="path/to/config.conf:system_service_name"
SERVICES["nginx"]="/etc/nginx/nginx.conf:nginx"
```

####  Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/YOUR_USERNAME/Shell-Script-Tool-Repository/issues) if you want to contribute.

####  License
This project is open source and available under the [MIT License](LICENSE).


祝你的开源项目 Star 越来越多！如果需要针对某个具体功能再补充说明，随时告诉我。

