FROM ubuntu:22.04

# SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
      apt-get install -y python3 git gcc g++ gdb cmake ninja-build make wget curl xz-utils bzip2 zip unzip gnupg && \
      curl -sS https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/llvm.gpg && \
      echo "deb [signed-by=/etc/apt/trusted.gpg.d/llvm.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-16 main" >> /etc/apt/sources.list.d/llvm.list && \
      echo "deb-src [signed-by=/etc/apt/trusted.gpg.d/llvm.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-16 main" >> /etc/apt/sources.list.d/llvm.list && \
      apt-get update && \
      apt-get install -y clang-16 lld-16 && \
      apt-get remove -y gnupg && \
      apt-get -y clean && \
      apt-get -y autoclean && \
      rm -rf /var/lib/apt/lists/*

WORKDIR /root

RUN git clone --depth 1 --branch v0.39.3 https://github.com/nvm-sh/nvm.git /opt/.nvm && \
      rm -rf /opt/.nvm/.git && \
      chmod +x /opt/.nvm/nvm.sh && /opt/.nvm/nvm.sh && \
      echo "export NVM_DIR=\"/opt/.nvm\"" >> $HOME/.bashrc && \
      echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> $HOME/.bashrc && \
      echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"" >> $HOME/.bashrc && \
      bash -c "source /opt/.nvm/nvm.sh && nvm install 20.4.0 && nvm use 20.4.0"

ENV NVM_DIR=/opt/.nvm \
    EMSDK=/opt/emsdk \
    LLVM_PATH=/usr/lib/llvm-16 \
    WABT_PATH=/opt/wabt

RUN git clone https://github.com/emscripten-core/emsdk.git $EMSDK && \
      cd $EMSDK && \
      $EMSDK/emsdk install releases-3.1.43 && \
      echo "import os" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "EMSCRIPTEN_ROOT = os.path.join(os.getenv('EMSDK'), 'upstream/emscripten')" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "NODE_JS = 'node'" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "PYTHON = 'python3'" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "JAVA = 'java'" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "LLVM_ROOT = os.path.join(os.getenv('EMSDK'), 'upstream/bin')" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "BINARYEN_ROOT = os.path.join(os.getenv('EMSDK'), 'upstream')" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "COMPILER_ENGINE = NODE_JS" >> $EMSDK/upstream/emscripten/.emscripten && \
      echo "JS_ENGINES = [NODE_JS]" >> $EMSDK/upstream/emscripten/.emscripten && \
      $EMSDK/upstream/emscripten/emcc -v

COPY ./*.sh ./tmp/

RUN chmod +x ./tmp/*.sh && \
    ./tmp/build-wasi.sh && \
    ./tmp/build-wabt.sh && \
    rm -rf ./tmp

ENV PATH="$LLVM_PATH/bin:$PATH:$EMSDK:$EMSDK/upstream/emscripten:$EMSDK/upstream/bin:$WABT_PATH/bin"

CMD ["/bin/bash"]
