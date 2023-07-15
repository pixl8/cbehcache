#!/bin/bash

rm -rf artifacts/*
mvn package || exit 1
cd artifacts
unzip cbehcache-1.0.0.jar
echo "Manifest-Version: 1.0
Bundle-ManifestVersion: 2
Bundle-Name: CBEHCache Java Service
Bundle-SymbolicName: org.pixl8.cbehcache
Bundle-Version: 1.0.0
" > META-INF/MANIFEST.MF
rm cbehcache-1.0.0.jar
zip -rq cbehcache-1.0.0.jar *

cp cbehcache-1.0.0.jar ../../lib/
