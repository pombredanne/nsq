#!/bin/bash
set -e

# build and run nsqlookupd
echo "building and starting nsqlookupd"
go build -o apps/nsqlookupd/nsqlookupd ./apps/nsqlookupd/
apps/nsqlookupd/nsqlookupd >/dev/null 2>&1 &
LOOKUPD_PID=$!

# build and run nsqd configured to use our lookupd above
cmd="apps/nsqd/nsqd --data-path=/tmp --lookupd-tcp-address=127.0.0.1:4160 --tls-cert=nsqd/test/certs/cert.pem --tls-key=nsqd/test/certs/key.pem"
echo "building and starting $cmd"
go build -o apps/nsqd/nsqd ./apps/nsqd
$cmd >/dev/null 2>&1 &
NSQD_PID=$!

sleep 0.3

cleanup() {
    kill -s TERM $NSQD_PID
    kill -s TERM $LOOKUPD_PID
}
trap cleanup INT TERM EXIT

go test -v -timeout 60s ./...
race="-race"
if go version | grep -q go1.0; then
    race=""
fi
GOMAXPROCS=4 go test -v -timeout 60s $race ./...

# no tests, but a build is something
for dir in nsqadmin apps/* bench/*; do
    echo "building $dir"
    go build -o $dir/$(basename $dir) ./$dir
done
