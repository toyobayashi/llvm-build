FROM ubuntu:22.04

# SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
      apt-get install -y vim file python3 git gcc g++ gdb cmake ninja-build make wget curl xz-utils bzip2 zip unzip gnupg openjdk-11-jre-headless && \
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

# RUN git clone --depth 1 --branch v0.39.3 https://github.com/nvm-sh/nvm.git /root/.nvm && \
#       rm -rf /root/.nvm/.git && \
#       chmod +x /root/.nvm/nvm.sh && /root/.nvm/nvm.sh && \
#       echo "export NVM_DIR=\"/root/.nvm\"" >> $HOME/.bashrc && \
#       echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> $HOME/.bashrc && \
#       echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"" >> $HOME/.bashrc && \
#       bash -c "source /root/.nvm/nvm.sh && nvm install 20.4.0 && nvm use 20.4.0"

RUN git clone --depth 1 --branch v0.39.3 https://github.com/nvm-sh/nvm.git /root/.nvm && \
      rm -rf /root/.nvm/.git && \
      chmod +x /root/.nvm/nvm.sh && /root/.nvm/nvm.sh && \
      bash -c "source /root/.nvm/nvm.sh && nvm install 20.4.0" && \
      cp -rpf /root/.nvm/versions/node/v20.4.0/bin/* /usr/local/bin && \
      cp -rpf /root/.nvm/versions/node/v20.4.0/include/* /usr/local/include && \
      cp -rpf /root/.nvm/versions/node/v20.4.0/lib/* /usr/local/lib && \
      cp -rpf /root/.nvm/versions/node/v20.4.0/share/* /usr/local/share && \
      rm -rf /root/.nvm && \
      rm -rf /root/.npm

ENV LLVM_PATH=/usr/lib/llvm-16 \
    BINARYEN_PATH=/opt/binaryen \
    EMSCRIPTEN_PATH=/opt/emscripten \
    WABT_PATH=/opt/wabt

RUN git clone https://github.com/emscripten-core/emsdk.git /root/emsdk && \
      /root/emsdk/emsdk install releases-3.1.43 && \
      mv -f /root/emsdk/upstream/emscripten $EMSCRIPTEN_PATH && \
      mv -f /root/emsdk/upstream $BINARYEN_PATH && \
      echo "import os" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "EMSCRIPTEN_ROOT = os.getenv('EMSCRIPTEN_PATH')" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "NODE_JS = 'node'" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "PYTHON = 'python3'" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "JAVA = 'java'" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "LLVM_ROOT = os.path.join(os.getenv('BINARYEN_PATH'), 'bin')" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "BINARYEN_ROOT = os.getenv('BINARYEN_PATH')" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "COMPILER_ENGINE = NODE_JS" >> $EMSCRIPTEN_PATH/.emscripten && \
      echo "JS_ENGINES = [NODE_JS]" >> $EMSCRIPTEN_PATH/.emscripten && \
      rm -rf /root/emsdk && \
      $EMSCRIPTEN_PATH/emcc -v

COPY --chmod=755 ./*.sh ./tmp/

RUN ./tmp/install-wasmtime.sh && \
    ./tmp/build-wasi.sh && \
    ./tmp/build-wabt.sh && \
    rm -rf ./tmp

ENV PATH="$LLVM_PATH/bin:$PATH:$EMSCRIPTEN_PATH:$BINARYEN_PATH/bin:$WABT_PATH/bin"

CMD ["/bin/bash"]
