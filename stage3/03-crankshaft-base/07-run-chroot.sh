#!/bin/bash -e
# fix Pi2 eglfs on Trixie for arm64
ln -s /opt/vc/lib/libbrcmEGL.so /usr/lib/aarch64-linux-gnu/libEGL.so
ln -s /opt/vc/lib/libbrcmGLESv2.so /usr/lib/aarch64-linux-gnu/libGLESv2.so
ln -s /opt/vc/lib/libbrcmOpenVG.so /usr/lib/aarch64-linux-gnu/libOpenVG.so
ln -s /opt/vc/lib/libbrcmWFC.so /usr/lib/aarch64-linux-gnu/libWFC.so
