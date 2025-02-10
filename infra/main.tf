terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.85.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_dynamodb_table" "tasks" {
  name         = "tasks-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "task_id"

  attribute {
    name = "task_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "due_date"
    type = "S"
  }

  # Option to filter tasks by status and due date

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "due-date-index"
    hash_key        = "due_date"
    projection_type = "ALL"
  }
}

# ---------------------------------------------
# Deploy Lambda Functions (Create, Get, Delete)
# ---------------------------------------------

data "archive_file" "create_task" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../src/create_task.zip"
}

resource "aws_lambda_function" "create_task" {
  filename      = "${path.module}/../src/create_task.zip"
  function_name = "create_task"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "create_task.lambda_handler"
  runtime       = "python3.8"
}

data "archive_file" "delete_task" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../src/delete_task.zip"
}

resource "aws_lambda_function" "delete_task" {
  filename      = "${path.module}/../src/delete_task.zip"
  function_name = "delete_task"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "delete_task.lambda_handler"
  runtime       = "python3.12"
}

data "archive_file" "get_task" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../src/get_task.zip"
}

resource "aws_lambda_function" "get_task" {
  filename      = "${path.module}/../src/get_task.zip"
  function_name = "get_task"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "get_task.lambda_handler"
  runtime       = "python3.8"
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

# Policy that allows Lambda to access DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name   = "lambda_dynamodb_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Resource = aws_dynamodb_table.tasks.arn
      }
    ]
  })
}

# Attach the policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# ---------------------------------------------
# Create an API Gateway for Task Management
# ---------------------------------------------

# Create the REST API
resource "aws_api_gateway_rest_api" "task_api" {
  name        = "TaskAPI"
  description = "API for managing tasks"
}

# Define the tasks resource
resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "{task_id}"
}

# Define a POST method for creating tasks
resource "aws_api_gateway_method" "post_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration of POST method with Lambda function
resource "aws_api_gateway_integration" "post_task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.post_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_task.invoke_arn
}

# Grant API Gateway permission to invoke Lambda function
resource "aws_lambda_permission" "apigw_post_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
}

# Define the GET method for retrieving tasks

resource "aws_api_gateway_method" "get_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.get_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_task.invoke_arn
}

resource "aws_lambda_permission" "apigw_get_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
}

# Define the DELETE method for deleting tasks

resource "aws_api_gateway_method" "delete_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.delete_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_task.invoke_arn
}

resource "aws_lambda_permission" "apigw_delete_task" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
}



# Create API Gateway Deployment
resource "aws_api_gateway_deployment" "task_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_task_integration,
    aws_api_gateway_integration.get_task_integration,
    aws_api_gateway_integration.delete_task_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.task_api))
  }
}

# Define API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.task_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  stage_name    = "prod"
}
