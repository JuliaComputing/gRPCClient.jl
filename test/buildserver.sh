#!/bin/bash
set -e

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${BASEDIR}

export PATH="$PATH:$(go env GOPATH)/bin"

git clone -b v1.35.0 https://github.com/grpc/grpc-go
cd grpc-go/examples/route_guide
protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative routeguide/route_guide.proto
sed 's/localhost/0.0.0.0/g' server/server.go > server/server.go.new
rm server/server.go
mv server/server.go.new server/server.go

export GOOS=linux
export GOARCH=amd64
echo "building runserver_${GOOS}_${GOARCH}..."
go build -o runserver_${GOOS}_${GOARCH} -i server/server.go
export GOARCH=386
echo "building runserver_${GOOS}_${GOARCH}..."
go build -o runserver_${GOOS}_${GOARCH} -i server/server.go
export GOOS=windows
export GOARCH=amd64
echo "building runserver_${GOOS}_${GOARCH}..."
go build -o runserver_${GOOS}_${GOARCH}.exe -i server/server.go
export GOARCH=386
echo "building runserver_${GOOS}_${GOARCH}..."
go build -o runserver_${GOOS}_${GOARCH}.exe -i server/server.go
export GOOS=darwin
export GOARCH=amd64
echo "building runserver_${GOOS}_${GOARCH}..."
go build -o runserver_${GOOS}_${GOARCH} -i server/server.go

mkdir -p ${BASEDIR}/runserver
cp runserver_* ${BASEDIR}/runserver/
