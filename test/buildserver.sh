#!/bin/bash
set -e

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export PATH="$PATH:$(go env GOPATH)/bin"
mkdir -p ${BASEDIR}/testservers

# build routeguide server
cd ${BASEDIR}
if [ ! -d "grpc-go" ]
then
    git clone -b v1.35.0 https://github.com/grpc/grpc-go
fi

cd grpc-go/examples/route_guide
protoc --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative routeguide/route_guide.proto
sed 's/localhost/0.0.0.0/g' server/server.go > server/server.go.new
rm server/server.go
mv server/server.go.new server/server.go

export GOOS=linux
export GOARCH=amd64
echo "building routeguide_${GOOS}_${GOARCH}..."
go build -o routeguide_${GOOS}_${GOARCH} -i server/server.go
export GOARCH=386
echo "building routeguide_${GOOS}_${GOARCH}..."
go build -o routeguide_${GOOS}_${GOARCH} -i server/server.go
export GOOS=windows
export GOARCH=amd64
echo "building routeguide_${GOOS}_${GOARCH}..."
go build -o routeguide_${GOOS}_${GOARCH}.exe -i server/server.go
export GOARCH=386
echo "building routeguide_${GOOS}_${GOARCH}..."
go build -o routeguide_${GOOS}_${GOARCH}.exe -i server/server.go
export GOOS=darwin
export GOARCH=amd64
echo "building routeguide_${GOOS}_${GOARCH}..."
go build -o routeguide_${GOOS}_${GOARCH} -i server/server.go

cp routeguide_* ${BASEDIR}/testservers/

# build grpcerrors server
cd ${BASEDIR}
cd error_test_server

export GOOS=linux
export GOARCH=amd64
echo "building grpcerrors_${GOOS}_${GOARCH}..."
go build -o grpcerrors_${GOOS}_${GOARCH} -i server.go
export GOARCH=386
echo "building grpcerrors_${GOOS}_${GOARCH}..."
go build -o grpcerrors_${GOOS}_${GOARCH} -i server.go
export GOOS=windows
export GOARCH=amd64
echo "building grpcerrors_${GOOS}_${GOARCH}..."
go build -o grpcerrors_${GOOS}_${GOARCH}.exe -i server.go
export GOARCH=386
echo "building grpcerrors_${GOOS}_${GOARCH}..."
go build -o grpcerrors_${GOOS}_${GOARCH}.exe -i server.go
export GOOS=darwin
export GOARCH=amd64
echo "building grpcerrors_${GOOS}_${GOARCH}..."
go build -o grpcerrors_${GOOS}_${GOARCH} -i server.go

cp grpcerrors_* ${BASEDIR}/testservers/
