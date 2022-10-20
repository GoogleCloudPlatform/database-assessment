sudo apt install -y protobuf-compiler bazel podman podman-compose kubectl build-essential git curl wget g++ unzip ca-certificates google-cloud-sdk-app-engine-python ipython3 libaio1 libaio-dev python3.10-full python-is-python3 ruby3.0 ansible sshuttle python3-netaddr isolinux xorriso jq google-cloud-sdk \
 && sudo apt-get autoremove -y \
 && sudo apt-get clean -y
sudo apt update && sudo apt install bazel-5.1.1
curl -sSL https://install.python-poetry.org | python3 -


export PROTOC_VERSION="3.14.0"
export BAZEL_VERSION="5.1.1"
if [ `uname -m` = 'x86_64' ]; then PROTOC_ARCHITECTURE="x86_64"; else PROTOC_ARCHITECTURE="aarch_64"; fi \
    && curl -sS -L -o protoc.zip --output-dir /tmp/ --create-dirs "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${PROTOC_ARCHITECTURE}.zip" \
    && curl -sS -L -o bazel --output-dir ~/.local/bin/ --create-dirs "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-${PROTOC_ARCHITECTURE}" \
    && unzip /tmp/protoc.zip -d ~/.local bin/protoc \
    && chmod +x ~/.local/bin/bazel \
    && ~/.local/bin/bazel \
    && rm -rf /tmp/protoc.zip

# oracle instant client
if [ `uname -m` = 'x86_64' ]; then ORA_ARCHITECTURE="x64"; else ORA_ARCHITECTURE="aarch_64"; fi \
    && mkdir -p /usr/share/oracle/network/admin \
    && cd /usr/share/oracle \
    && curl -sS -L -o instantclient.zip --output-dir /usr/share/oracle/ https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linux${ORA_ARCHITECTURE}.zip \
    && unzip /usr/share/oracle/instantclient.zip \
    && rm -f instantclient.zip \
    && cd  /usr/share/oracle/instantclient* \
    && rm -f *jdbc* *occi* *mysql* *README *jar uidrvci genezi adrci \
    && echo  /usr/share/oracle/instantclient* > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig
