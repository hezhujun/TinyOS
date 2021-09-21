#!/bin/bash

wget -c https://udomain.dl.sourceforge.net/project/bochs/bochs/2.6.2/bochs-2.6.2.tar.gz -O bochs-2.6.2.tar.gz
tar -zxf bochs-2.6.2.tar.gz
rm bochs-2.6.2.tar.gz

BOCHS_HOME=$(pwd)/bochs
cd bochs-2.6.2
./configure \
  --prefix=/$BOCHS_HOME \
  --enable-debugger \
  --enable-disasm \
  --enable-iodebug \
  --enable-x86-debugger \
  --with-x \
  --with-x11 

sed -i '92cLIBS =  -lm -lgtk-x11-2.0 -lgdk-x11-2.0 -lpangocairo-1.0 -latk-1.0 -lcairo -lgdk_pixbuf-2.0 -lgio-2.0 -lpangoft2-1.0 -lpango-1.0 -lgobject-2.0 -lglib-2.0 -lharfbuzz -lfontconfig -lfreetype -lpthread' Makefile
make && make install