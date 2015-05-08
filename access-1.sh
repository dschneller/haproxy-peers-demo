#!/bin/bash
for x in $(seq ${1} ${2}); do
   printf "%05d - " ${x};
   curl -H "Cookie: c1=1; c2=2; JSESSIONID=$(md5 -q -s _${x})" http://localhost:8081;
done
