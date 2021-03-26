#!/bin/bash
set -e

BASEDIR=$(dirname $0)
cd ${BASEDIR}

export PATH="$PATH:$(go env GOPATH)/bin"
CERT_FILE=../../../certgen/server.pem
KEY_FILE=../../../certgen/server.key
HOSTNAME=`hostname -f`

git clone -b v1.35.0 https://github.com/grpc/grpc-go
cd grpc-go/examples/route_guide
protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative routeguide/route_guide.proto
sed 's/localhost/0.0.0.0/g' server/server.go > server/server.go.new
rm server/server.go
mv server/server.go.new server/server.go
go build -o runserver -i server/server.go

./runserver --tls=true --cert_file=$CERT_FILE --key_file=$KEY_FILE &
echo $! > server.pid
echo "server pid `cat server.pid`"

NEXT_WAIT_TIME=0
until [ $NEXT_WAIT_TIME -eq 10 ] || nc -z 127.0.0.1 10000; do
    sleep $(( NEXT_WAIT_TIME++ ))
done
[ $NEXT_WAIT_TIME -lt 5 ]

echo "server listening"
