FROM almalinux:9

RUN dnf -y update \
  && dnf -y install \
    https://yum.overlookinfratech.com/openvox8-release-el-9.noarch.rpm \
    epel-release \
    yum-utils \
  && yum-config-manager --set-enabled crb \
  && dnf -y module enable ruby:3.3 \
  && dnf -y install \
    git \
    openvox-agent \
    openvox-server \
    ruby \
    ruby-devel \
    rubygem-rake \
    libyaml-devel \
    make \
    gcc \
    yamllint \
    jq \
    which \
    time \
    vim-enhanced \
    neovim \
    bash-completion \
    sudo \
  && dnf clean all

# Create a non-root user and set permissions
RUN useradd -ms /bin/bash vscode \
    && mkdir -p /workspace \
    && chown -R vscode:vscode /workspace \
    && echo vscode ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# Switch to the non-root user
USER vscode

# Set up bash-git-prompt
RUN git clone https://github.com/magicmonty/bash-git-prompt.git /home/vscode/.bash-git-prompt --depth 1 \
    && cat >> /home/vscode/.bashrc <<EOF

if [ -f ~/.bash-git-prompt/gitprompt.sh ]; then
    GIT_PROMPT_ONLY_IN_REPO=1
    . ~/.bash-git-prompt/gitprompt.sh
fi
EOF

# Set the working directory
WORKDIR /workspace
