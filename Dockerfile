FROM lambci/lambda-base-2:build

WORKDIR /build

ARG VIPS_VERSION=8.8.3

ENV WORKDIR="/build"
ENV INSTALLDIR="/opt"
ENV VIPS_VERSION=$VIPS_VERSION

# Install deps for libvips. Details: https://libvips.github.io/libvips/install.html
#
RUN yum install -y \
  gtk-doc \
  gobject-introspection \
  gobject-introspection-devel

RUN yum install -y expat-devel
RUN mkdir /usr/local/share/imagemagick 
COPY Makefile_ImageMagick /usr/local/share/imagemagick/Makefile
WORKDIR /usr/local/share/imagemagick
RUN make all && \
  echo /opt/lib > /etc/ld.so.conf.d/libmagick.conf && \
  ldconfig

WORKDIR ${WORKDIR}

# Clone repo and checkout version tag.
#
RUN git clone git://github.com/libvips/libvips.git && \
  cd libvips && \
  git checkout "v${VIPS_VERSION}"

# Compile from source.
#
RUN cd ./libvips && \
  CC=clang CXX=clang++ \
  ./autogen.sh \
  --prefix=${INSTALLDIR} \
  --disable-static && \
  make install && \
  echo /opt/lib > /etc/ld.so.conf.d/libvips.conf && \
  ldconfig

# Copy only needed so files to new share/lib.
#
RUN mkdir -p share/lib && \
  cp -a $INSTALLDIR/lib/libvips.so* $WORKDIR/share/lib/

# Create sym links for ruby-ffi gem's `glib_libname` and `gobject_libname` to work.
RUN cd ./share/lib/ && \
  ln -s /usr/lib64/libglib-2.0.so.0 libglib-2.0.so && \
  ln -s /usr/lib64/libgobject-2.0.so.0 libgobject-2.0.so

# Zip up contents so final `lib` can be placed in /opt layer.
#
RUN cd ./share && \
  zip --symlinks -r libvips.zip .
