provider "aws" {
  region = var.region
}

# Lambda Permission to allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

# Create the REST API
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.api_gateway_name
  description = var.api_gateway_description
}

# Create the root resource (/)
resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = var.root_path_part
}

# Create a child resource (/example)
resource "aws_api_gateway_resource" "example" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.root.id
  path_part   = var.child_resource_path
}

# Create the GET method for the /example resource
resource "aws_api_gateway_method" "example_get" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "GET"
  authorization = "NONE"
}

# Lambda Integration for the GET method on /example
resource "aws_api_gateway_integration" "lambda_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.example_get.resource_id
  http_method = aws_api_gateway_method.example_get.http_method
  type        = "AWS_PROXY"

  integration_http_method = "POST"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

# Create the POST method for the /example resource
resource "aws_api_gateway_method" "example_post" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda Integration for the POST method on /example
resource "aws_api_gateway_integration" "lambda_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.example_post.resource_id
  http_method = aws_api_gateway_method.example_post.http_method
  type        = "AWS_PROXY"

  integration_http_method = "POST"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

# Deploy the API
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = var.stage_name

  depends_on = [
    aws_api_gateway_integration.lambda_get_integration,
    aws_api_gateway_integration.lambda_post_integration
  ]
}

# Create a stage for the deployment
resource "aws_api_gateway_stage" "api_stage" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
}

# Output the API Gateway URL
output "api_gateway_url" {
  value = aws_api_gateway_stage.api_stage.invoke_url
}
