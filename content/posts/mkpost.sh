#!/bin/bash
set -euxo pipefail
cd `dirname $0`

name=`date '+%Y%m%d%H%M'`
mkdir $name
cp test/index.md $name/index.md
