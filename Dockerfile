FROM registry.access.redhat.com/ubi9/podman

RUN set -x && \
    dnf --disableplugin=subscription-manager update -y && \
    dnf --disableplugin=subscription-manager upgrade -y && \
    dnf --disableplugin=subscription-manager install -y python3-pip jq openssh-clients && \
    dnf --disableplugin=subscription-manager autoremove

ARG USER=runner
ARG UID=1001
ARG HOME=/home/$USER

RUN set -x && \
    useradd --create-home --uid $UID --gid 0 $USER

WORKDIR $HOME/ansible

RUN chown -R ${USER}:0 $HOME

USER $USER

ENV PATH $HOME/.local/bin:$PATH

RUN set -x && \
    python3 -m pip install --no-cache-dir --upgrade --user pip && \
    python3 -m pip install --no-cache-dir --upgrade --user ansible && \
    python3 -m pip install --no-cache-dir --upgrade --user kubernetes && \
    python3 -m pip install --no-cache-dir --upgrade --user netaddr && \
    python3 -m pip install --no-cache-dir --upgrade --user dnspython

LABEL ansible-automation.description="Ansible automation I have gathered in my travels over the years combined into a layout I have found to be useful."
LABEL ansible-automation.maintainer="Glenn Marcy <ansible-automation@gmarcy.com>"
LABEL ansible-automation.thanks="https://github.com/IBM/community-automation, https://github.com/Kubeinit/kubeinit, and many others for the pearls of wisdom you have shown me."

ENTRYPOINT ["ansible-playbook", "-e", "running_in_container=true"]

COPY --chown=${USER}:0 . .

RUN set -x && \
    ansible-playbook build-container-playbook.yml
