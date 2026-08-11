FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System packages required by the Flutter SDK (git/curl to fetch, xz/unzip to
# extract, ca-certificates for TLS, libglu1-mesa for tooling).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        unzip \
        xz-utils \
        zip \
        ca-certificates \
        libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Flutter 3.7.12 is the last stable release shipping Dart 2.x (2.19.6). Every
# example in this repo pins an SDK constraint of "<3.0.0", so a Dart 3 toolchain
# would refuse `flutter pub get`. Pin this version deliberately.
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH

RUN curl -fSL -o /tmp/flutter.tar.xz \
        https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.7.12-stable.tar.xz \
    && mkdir -p /opt \
    && tar xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && chown -R ubuntu:ubuntu /opt/flutter

USER ubuntu

# Mark the SDK checkout as a safe git directory for the runtime user, silence
# first-run analytics prompts, and warm the web artifact cache so the examples
# can be run/built for the web target out of the box.
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics \
    && flutter precache --web \
    && flutter doctor
