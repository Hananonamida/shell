# 使用基础镜像
FROM hananonamida/gaganode:1.0.4

# 定义环境变量
ENV TOKEN=default_token

# 公开端口
EXPOSE 36060

# 设置容器启动命令
CMD ["sh", "-c", "/app/Cli start accept --token $TOKEN --restart=always"]
