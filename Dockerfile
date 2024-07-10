# 使用基础镜像
FROM traffmonetizer/cli_v2:latest

# 定义环境变量
ENV TOKEN=default_token

# 公开端口
EXPOSE 8080

# 设置容器启动命令
CMD ["sh", "-c", "/app/Cli start accept --token $TOKEN --restart=always"]
