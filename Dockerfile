FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://golang.google.cn/dl/go1.21.6.linux-amd64.tar.gz | tar -C /usr/local -xzf - && \
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile && \
    ln -s /usr/local/go/bin/go /usr/local/bin/go

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GO111MODULE=on

WORKDIR /workspace

RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple openai python-dotenv requests

RUN useradd -m -s /bin/bash openclaw && chown -R openclaw:openclaw /workspace

USER openclaw

CMD ["bash"]
