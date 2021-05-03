package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"time"

	"google.golang.org/grpc"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/status"

	pb "juliacomputing.com/errortest/grpcerrors"
)

var (
	tls      = flag.Bool("tls", false, "Connection uses TLS if true, else plain TCP")
	certFile = flag.String("cert_file", "", "The TLS cert file")
	keyFile  = flag.String("key_file", "", "The TLS key file")
	port     = flag.Int("port", 10000, "The server port")
)

type gRPCErrorsServer struct {
	pb.UnimplementedGRPCErrorsServer
}

func (gRPCErrorsServer) SimpleRPC(ctx context.Context, data *pb.Data) (*pb.Data, error) {
	if data.Mode == 1 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		return data, errors.New("simulated error mode 1")
	} else if data.Mode == 2 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		return data, nil
	} else {
		return nil, status.Errorf(codes.Unimplemented, "mode not implemented")
	}
}

func (gRPCErrorsServer) StreamResponse(data *pb.Data, stream pb.GRPCErrors_StreamResponseServer) error {
	if data.Mode == 1 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		return errors.New("simulated error mode 1")
	} else if data.Mode == 2 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		if err := stream.Send(data); err != nil {
			return err
		}
		return nil
	} else {
		return status.Errorf(codes.Unimplemented, "mode not implemented")
	}
}

func (gRPCErrorsServer) StreamRequest(stream pb.GRPCErrors_StreamRequestServer) error {
	data, err := stream.Recv()
	if err == io.EOF {
		return nil
	}
	if err != nil {
		return err
	}

	if data.Mode == 1 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		return errors.New("simulated error mode 1")
	} else if data.Mode == 2 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		return stream.SendAndClose(data)
	} else {
		return status.Errorf(codes.Unimplemented, "mode not implemented")
	}
}

func (gRPCErrorsServer) StreamRequestResponse(stream pb.GRPCErrors_StreamRequestResponseServer) error {
	data, err := stream.Recv()
	if err == io.EOF {
		return nil
	}
	if err != nil {
		return err
	}

	if data.Mode == 1 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		return errors.New("simulated error mode 1")
	} else if data.Mode == 2 {
		time.Sleep(time.Duration(int64(data.Param)) * time.Second)
		if err := stream.Send(data); err != nil {
			return err
		}
		return nil
	} else {
		return status.Errorf(codes.Unimplemented, "mode not implemented")
	}
}

func newServer() *gRPCErrorsServer {
	s := &gRPCErrorsServer{}
	return s
}

func main() {
	flag.Parse()
	lis, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", *port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	var opts []grpc.ServerOption
	if *tls {
		creds, err := credentials.NewServerTLSFromFile(*certFile, *keyFile)
		if err != nil {
			log.Fatalf("Failed to generate credentials %v", err)
		}
		opts = []grpc.ServerOption{grpc.Creds(creds)}
	}
	grpcServer := grpc.NewServer(opts...)
	pb.RegisterGRPCErrorsServer(grpcServer, newServer())
	grpcServer.Serve(lis)
}
