package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/segmentio/kafka-go"
	"github.com/segmentio/kafka-go/sasl/plain"
)

func produce(key, value string) error {
	partition := 0
	topic := "dr2"
	url := "xxxx:9094"
	user := "yyyy"
	password := "xxxxxxxx"

	log.Printf("Connecting to %s with user:%s partition:%d...\n", url, user, partition)
	dialer := &kafka.Dialer{
		Timeout:   3 * time.Second,
		DualStack: true,
		TLS: &tls.Config{
			InsecureSkipVerify: true,
		},
		SASLMechanism: plain.Mechanism{
			Username: user,
			Password: password,
		},
	}
	log.Printf("Before .DialLeader")
	conn, err := dialer.DialLeader(context.Background(), "tcp", url, topic, partition)
	log.Printf("After .DialLeader")
	if err != nil {
		log.Printf("Error in dialer: %s\n", err)
		return err
	}
	defer conn.Close()

	msg := kafka.Message{
		Key:   []byte(key),
		Value: []byte(value),
	}
	log.Printf("Before write message")
	_, err = conn.WriteMessages(msg)
	if err != nil {
		return err
	} else {
		log.Printf("Produced message with key: %s value: %s\n", key, value)
	}

	return nil
}

func handleRequest(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	value := req.PathParameters["value"]
	if value == "" {
		return events.APIGatewayProxyResponse{Body: "No value provided", StatusCode: 404}, nil
	}

	t := int(time.Now().Unix())
	key := fmt.Sprintf("Key-%d", t)
	log.Printf("Trying to send to kafka key: %s value: %s\n", key, value)
	err := produce(key, value)
	if err != nil {
		log.Printf("ERROR from producer: %s\n", err)
		return events.APIGatewayProxyResponse{Body: "Problems sending msg to kafka", StatusCode: 500}, nil
	}

	return events.APIGatewayProxyResponse{Body: "ok", StatusCode: 200}, nil
}

func main() {
	lambda.Start(handleRequest)
}
