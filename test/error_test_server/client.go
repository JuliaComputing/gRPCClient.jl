package main

import (
    "context"
    "flag"
    "log"
    "time"

    "google.golang.org/grpc"
	pb "juliacomputing.com/errortest/grpcerrors"
)

var (
    tls                = flag.Bool("tls", false, "Connection uses TLS if true, else plain TCP")
    caFile             = flag.String("ca_file", "", "The file containing the CA root cert file")
    serverAddr         = flag.String("server_addr", "localhost:10000", "The server address in the format of host:port")
    serverHostOverride = flag.String("server_host_override", "x.test.youtube.com", "The server name used to verify the hostname returned by the TLS handshake")
)

func simpleRPC(client pb.GRPCErrorsClient, data *pb.Data) {
    log.Printf("Calling simpleRPC for data (%d, %d)", data.Mode, data.Param)
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()
    respdata, err := client.SimpleRPC(ctx, data)
    if err != nil {
        log.Fatalf("%v.SimpleRPC(_) = _, %v: ", client, err)
    }
    log.Println(respdata)
}

func main() {
    flag.Parse()
    var opts []grpc.DialOption
    opts = append(opts, grpc.WithInsecure())
    opts = append(opts, grpc.WithBlock())
    conn, err := grpc.Dial(*serverAddr, opts...)
    if err != nil {
        log.Fatalf("fail to dial: %v", err)
    }
    defer conn.Close()
    client := pb.NewGRPCErrorsClient(conn)

    // simpel RPC
    simpleRPC(client, &pb.Data{Mode: 1, Param: 0})
}

