#!/usr/bin/env bash

# we want jruby-complete to take care of all things ruby
unset GEM_HOME
unset GEM_PATH

JAVA_OPTS="-client -Xmx2048m -XX:ReservedCodeCacheSize=256m"

java_version=`java -version 2>&1 | sed 's/java version "1\.\(.*\)\..*"/\1/; 1q'`

if [[ "$java_version" > 7 ]]
then
  JAVA_OPTS="$JAVA_OPTS -XX:MetaspaceSize=1024m"
else
  JAVA_OPTS="$JAVA_OPTS -XX:MaxPermSize=1024m"
fi

java $JAVA_OPTS -jar third_party/jruby/jruby-complete.jar -X-C -S rake $*

