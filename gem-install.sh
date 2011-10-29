#!/bin/bash
GEM_PATH=`pwd`/lib/jruby/1.9 java -jar ~/.m2/repository/org/jruby/jruby-complete/1.6.5/jruby-complete-1.6.5.jar --1.9 -S gem install "$@" --no-ri --no-rdoc -i lib/jruby/1.9/

