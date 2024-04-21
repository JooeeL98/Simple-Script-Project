#!/bin/bash

# 1- Store the AWS account ID in varible
aws_account_ID=$(aws sts get-caller-identity --query Account --output text)

# 2- Print the AWS account ID form the variable
echo "AWS account ID: $aws_account_ID"

# 3- Set AWS region, bucket name, lambda function-name, role name and email-address
aws_region="us-east-1"
bucket_name="simple-script-project-s3"
lambda_function_name="lambda-function-s3"
role_name="s3-lambda-sns"
email_address="youremail@gmail.com"

# 4- Create IAM Role for the project
role_response=$(aws iam create-role --role-name $role_name --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "s3.amazonaws.com",
	  "sns.amazonaws.com"
        ]
      }
    }]
}' --region "$aws_region")

# 5- Extract the role ARN from the JSON response and store it in a variable
role_arn=$(echo "$role_response" | jq -r '.Role.Arn')

# 6- Print the role ARN 
echo "Role ARN: $role_arn"

# 7- Attach permissions to the Role
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# 8- Create the S3 bucket and capture the output in a variable
bucket_output=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region") 

# 9- Print the output from the variable
echo "S3 Bucket output: $bucket_output"

# 10- Upload a file to the bucket
aws s3 cp ./ejemplo.txt s3://"$bucket_name"/ejemplo.txt

echo "aqui1"
# 11- Create a Zip file to upload Lambda function
zip -r s3-lambda-function.zip ./s3-lambda-function

echo "aqui2"
sleep 5

# 12- Create a Lambda Fuction
aws lambda create-function \
	--region "$aws_region" \
	--function-name $lambda_function_name \
	--runtime "python3.8" \
	--handler "s3-lambda-function/s3-lambda-function.lambda_handler" \
	--memory-size 128 \
	--timeout 30 \
	--role "arn:aws:iam::$aws_account_ID:role/$role_name" \
	--zip-file "fileb://./s3-lambda-function.zip"

echo "aqui3"
# 13- Add Permissions to S3 Bucket to invoke Lambda
aws lambda add-permission \
	--function-name "$lambda_function_name" \
	--statement-id "s3-lambda-sns" \
	--region "$aws_region" \
	--principal s3.amazonaws.com \
	--action "lambda:InvokeFunction" \
	--source-arn "arn:aws:s3:::$bucket_name"

# 14- Create an S3 event trigger for the Lambda function
LambdaFunctionArn="arn:aws:lambda:$aws_region:$aws_account_ID:function:s3-lambda-function"
aws s3api put-bucket-notification-configuration \
	--region "$aws_region" \
	--bucket "$bucket_name" \
	--notification-configuration '{
	  "LambdaFunctionConfigurations": [{
	      "LambdaFunctionArn":"'"$LambdaFunctionArn"'",
	      "Events": ["s3:ObjectCreated:*"]
	  }]
      }'

# 15- Create an SNS topic and save the topic ARN to variable
topic_arn=$(aws sns create-topic --name s3-lambda-sns --region "$aws_region" --output json | jq -r '.TopicArn')

# 16- Print the topic ARN
echo "SNS Topic Arn: $topic_arn"

# 17- Trigger SNS topic using Lambda Function

# 18- Add SNS publish permission to the Lambda Function
aws sns subscribe \
	--topic-arn "$topic_arn" \
	--protocol email \
	--notification-endpoint "$email_address"

# 19- Publish SNS
aws sns publish \
	--topic-arn "$topic_arn" \
	--subject "A new object created in s3 bucket" \
	--message "Hola Soy Joel, disfruta de este contenido :)"

