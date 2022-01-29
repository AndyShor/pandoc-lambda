# Define versionsbash
ARG FUNCTION_DIR="/var/task"
ARG GHC_VERSION="8.4.4"
ARG EPEL_VERSION="latest-7"
ARG TARGET_DIR="/opt/"

FROM lambci/lambda-base-2:build as pandoc-image

# Install aws-lambda-cpp build dependencies

ARG FUNCTION_DIR
ARG GHC_VERSION
ARG EPEL_VERSION
ARG TARGET_DIR

WORKDIR /var/task

RUN cd /var/task &&\
  mkdir build &&\
  cd build &&\
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &&\
  rpm -i epel-release-${EPEL_VERSION}.noarch.rpm &&\
  yum install ghc -y &&\
  curl -LO https://downloads.haskell.org/~ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-x86_64-centos70-linux.tar.xz &&\
  tar xf ghc-${GHC_VERSION}-x86_64-centos70-linux.tar.xz && \
  rm ghc-${GHC_VERSION}-x86_64-centos70-linux.tar.xz && \
  cd ghc* &&\
  ./configure --prefix=/usr/local &&\
  make install && \
  cd .. &&\
  curl -LO https://downloads.haskell.org/cabal/cabal-install-2.2.0.0/cabal-install-2.2.0.0-x86_64-unknown-linux.tar.gz &&\
  tar xf cabal-install-2.2.0.0-x86_64-unknown-linux.tar.gz &&\
  mv cabal /usr/local/bin &&\
  cabal update &&\
  cabal sandbox init --sandbox . &&\
  cabal install --disable-documentation --force-reinstalls pandoc-2.7.2 -fembed_data_files &&\
  mkdir -p ${TARGET_DIR}bin &&\
  cp bin/pandoc ${TARGET_DIR}bin && \
  pip3 install requests --target ${FUNCTION_DIR} &&\
    pip3 install boto3 --target ${FUNCTION_DIR} &&\
    pip3 install   --target ${FUNCTION_DIR} awslambdaric &&\
    mkdir -p ${FUNCTION_DIR}/.aws-lambda-rie &&\
    curl -Lo ${FUNCTION_DIR}/.aws-lambda-rie/aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie &&\
    chmod +x ${FUNCTION_DIR}/.aws-lambda-rie/aws-lambda-rie 


FROM lambci/lambda-base-2:build as latex-image

ARG FUNCTION_DIR
ARG TARGET_DIR

# The TeXLive installer needs md5 and wget.
RUN yum -y update && \
    yum -y install perl-Digest-MD5 && \
    yum -y install wget

RUN mkdir /var/src
WORKDIR /var/src

# Copy in the build image dependencies
COPY --from=pandoc-image ${FUNCTION_DIR} ${FUNCTION_DIR}
COPY --from=pandoc-image ${TARGET_DIR} ${TARGET_DIR}
COPY app/* ${FUNCTION_DIR}


# Download TeXLive installer.
ADD http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz /var/src/


# Minimal TeXLive configuration profile.
COPY texlive.profile /var/src/

# Intstall base TeXLive system.
RUN tar xf install*.tar.gz
RUN cd install-tl-* && \
    ./install-tl --profile /var/src/texlive.profile --location http://ctan.mirror.norbert-ruehl.de/systems/texlive/tlnet


ENV PATH=/var/task/texlive/2021/bin/x86_64-linux/:$PATH

# Install extra packages.
RUN tlmgr install scheme-basic &&\
    tlmgr install xcolor\ 
       booktabs\
       etoolbox \
       footnotehyper\
       lualatex-math\
       unicode-math\
       latexmk


RUN mkdir -p /var/task/texlive/2021/tlpkg/TeXLive/Digest/ && \
    mkdir -p /var/task/texlive/2021/tlpkg/TeXLive/auto/Digest/MD5/ && \
    cp /usr/lib64/perl5/vendor_perl/Digest/MD5.pm \
       /var/task/texlive/2021/tlpkg/TeXLive/Digest/ && \
    cp /usr/lib64/perl5/vendor_perl/auto/Digest/MD5/MD5.so \
       /var/task/texlive/2021/tlpkg/TeXLive/auto/Digest/MD5 &&\
    cp ${FUNCTION_DIR}/.aws-lambda-rie/aws-lambda-rie /usr/local/bin/aws-lambda-rie


ENV PATH=/var/task/texlive/2021/bin/x86_64-linux/:$PATH
ENV PERL5LIB=/var/task/texlive/2021/tlpkg/TeXLive/

WORKDIR /var/task

ENTRYPOINT [ "/var/task/ric.sh" ]

CMD [ "handler.lambda_handler" ]










  




