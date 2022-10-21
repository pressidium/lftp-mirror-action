FROM alpine:3.15
LABEL maintainer="Konstantinos Pappas <konpap@pressidium.com>"

COPY LICENSE /
COPY README.md /

# Install packages
# We need `openssh-client` to run `ssh-keyscan`
# We need `git`, `python3`, and `py3-pip` to run `git-restore-mtime`
RUN apk add --no-cache bash openssh-client lftp git python3 py3-pip

# Install `git-restore-mtime` from GitHub releases
RUN wget -O ./git-restore-mtime.tar.gz https://github.com/MestreLion/git-tools/archive/refs/tags/v2022.07.tar.gz \
    && tar -xzf ./git-restore-mtime.tar.gz \
    && mv ./git-tools-2022.07/git-restore-mtime /usr/local/bin/git-restore-mtime \
    && rm -rf ./git-tools-2022.07 \
    && rm -f ./git-restore-mtime.tar.gz

# Copy our entrypoint script and make it executable
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
