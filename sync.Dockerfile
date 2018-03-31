FROM google/cloud-sdk:alpine
RUN curl https://dl.minio.io/client/mc/release/linux-amd64/mc > /usr/bin/mc && chmod +x /usr/bin/mc
COPY functions.bash /functions.bash
