PRJ_NAME=go-lambda-kafka
include .env

help:
	@echo "go λ kafka stack cmds: "
	@echo ""
	@echo "\$$ make install         # install go deps"
	@echo "\$$ make configure       # create bucket"
	@echo "\$$ make package         # build handlers and update S3 bucket"
	@echo "\$$ make deploy          # deploy CF stack"
	@echo "\$$ make outputs         # get CF outputs"
	@echo "\$$ make ping            # ping the /ping endpoint via curl "
	@echo "\$$ make produce/<value> # send data to /producer endpoint via curl"
	@echo "🤘"
	@echo "\$$ make package deploy"

ping:
	@URL=`make outputs | jq '.[0].OutputValue' | awk -F\" '{print $$2}'`;\
		echo "curl $$URL/ping";\
		curl $$URL/ping

produce/%:
	URL=`make outputs | jq '.[0].OutputValue' | awk -F\" '{print $$2}'`;\
		echo "curl $$URL/produce/$*";\
		curl $$URL/producer/$*

clean:
		@rm -rf dist
		@mkdir -p dist

build: clean go.mod
		@for dir in `ls handler`; do \
			GOOS=linux GOARCH=amd64 go build -o dist/handler/$$dir ./handler/$$dir; \
		done

go.mod:
	go mod init github.com/drio/$(PRJ_NAME)
	go mod tidy

run:
		aws-sam-local local start-api

install:
		go get github.com/aws/aws-lambda-go/events
		go get github.com/aws/aws-lambda-go/lambda
		go get github.com/stretchr/testify/assert
		go get github.com/segmentio/kafka-go

install-dev:
		go get github.com/awslabs/aws-sam-local

test:
		go test ./... --cover

configure:
	@if [ "$(AWS_REGION)" == "us-east-1" ];then \
		aws s3api create-bucket \
			--bucket $(AWS_BUCKET_NAME) \
			--region $(AWS_REGION); \
	else \
		aws s3api create-bucket \
			--bucket $(AWS_BUCKET_NAME) \
			--region $(AWS_REGION) \
			--create-bucket-configuration LocationConstraint=$(AWS_REGION); \
	fi

package: build
	@aws cloudformation package \
		--template-file template.yml \
		--s3-bucket $(AWS_BUCKET_NAME) \
		--region $(AWS_REGION) \
		--output-template-file package.yml

deploy:
		@aws cloudformation deploy \
			--template-file package.yml \
			--region $(AWS_REGION) \
			--capabilities CAPABILITY_IAM \
			--stack-name $(AWS_STACK_NAME)

describe:
		@aws cloudformation describe-stacks \
			--region $(AWS_REGION) \
			--stack-name $(AWS_STACK_NAME) \

outputs:
		@make describe | jq -r '.Stacks[0].Outputs'

url:
		@make describe | jq -r ".Stacks[0].Outputs[0].OutputValue" -j
