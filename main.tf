provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Define the API Gateway
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.name
  description = "API Gateway with Lambda integration (non-proxy) and CORS enabled"
}

# Loop over each resource in api_resources
resource "aws_api_gateway_resource" "api_resource" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = each.value.path_part
}

# Loop over each resource to create methods
resource "aws_api_gateway_method" "api_method" {
  for_each = var.api_resources

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = each.value.methods[0]  # Using the first method as an example
  authorization = "NONE"                 # Adjust as needed
}

# Integrate the methods with the respective Lambda function for each resource
resource "aws_api_gateway_integration" "lambda_integration" {
  for_each = var.api_resources

  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.api_resource[each.key].id
  http_method             = aws_api_gateway_method.api_method[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${each.value.lambda_function_arn}/invocations"

  # Remove dynamic references
  depends_on = [
    aws_api_gateway_method.api_method,  # Static reference to the methods
    aws_api_gateway_method_response.api_method_response  # Static reference to method responses
  ]
}

# Grant API Gateway permission to invoke the respective Lambda function for each resource
resource "aws_lambda_permission" "allow_api_gateway" {
  for_each = var.api_resources

  statement_id  = "AllowExecutionFromAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.rest_api.id}/*/*"
}

# Define method response for each method to handle CORS
resource "aws_api_gateway_method_response" "api_method_response" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.api_method[each.key].resource_id
  http_method = aws_api_gateway_method.api_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
  }
}

# Integrate the responses with the corresponding integration response
resource "aws_api_gateway_integration_response" "api_integration_response" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.api_resource[each.key].id
  http_method = aws_api_gateway_method.api_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'"
  }

  response_templates = {
    "application/json" = ""
  }

  # Remove dynamic references
  depends_on = [
    aws_api_gateway_method_response.api_method_response,  # Static reference to method responses
    aws_api_gateway_integration.lambda_integration  # Static reference to integrations
  ]
}

# Define OPTIONS method for CORS
resource "aws_api_gateway_method" "options_method" {
  for_each = var.api_resources

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integrate the OPTIONS method (dummy integration)
resource "aws_api_gateway_integration" "options_integration" {
  for_each = var.api_resources

  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.api_resource[each.key].id
  http_method             = aws_api_gateway_method.options_method[each.key].http_method
  # integration_http_method = "POST"  # Dummy method since we don't call a Lambda for OPTIONS
  type                    = "MOCK"  # Use MOCK integration for OPTIONS
  request_templates = {
    "application/json" = <<EOF
{
  "statusCode": 200
}
EOF
  }
}

# Define method response for OPTIONS
resource "aws_api_gateway_method_response" "options_method_response" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_method.options_method[each.key].resource_id
  http_method = aws_api_gateway_method.options_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true,
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
  }
}

# Define integration response for OPTIONS
resource "aws_api_gateway_integration_response" "options_integration_response" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_integration.options_integration[each.key].rest_api_id
  resource_id = aws_api_gateway_integration.options_integration[each.key].resource_id
  http_method = aws_api_gateway_method.options_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'",
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_method_response.options_method_response]
}

# Create a resource policy for the API Gateway
resource "aws_api_gateway_rest_api_policy" "rest_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "execute-api:Invoke",
        "Resource" : "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.rest_api.id}/*/*",
        "Condition" : {
          "IpAddress" : {
            "aws:SourceIp" : var.allowed_ips
          }
        }
      },
      {
        "Effect" : "Deny",
        "Principal" : "*",
        "Action" : "execute-api:Invoke",
        "Resource" : "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.rest_api.id}/*/*",
        "Condition" : {
          "NotIpAddress" : {
            "aws:SourceIp" : var.allowed_ips
          }
        }
      }
    ]
  })
}

# Deploy the API
# API Gateway Deployment
# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration_response.api_integration_response,
    aws_api_gateway_integration_response.options_integration_response,
    aws_lambda_permission.allow_api_gateway,
    aws_api_gateway_method_response.api_method_response,
    aws_api_gateway_method_response.options_method_response,
    aws_api_gateway_method.api_method,
    aws_api_gateway_method.options_method,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_resource.api_resource
  ]

  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  lifecycle {
    create_before_destroy = false  # Ensures that the new deployment is created before destroying the old one
  }

  # Dynamic triggers to force a new deployment on changes
  triggers = {
    deployment_timestamp = timestamp()
    api_resources_hash   = md5(jsonencode(aws_api_gateway_resource.api_resource))
  }
}

# API Gateway Stage (depends on the deployment)
resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "prod"
  deployment_id = aws_api_gateway_deployment.api_deployment.id

  lifecycle {
    #create_before_destroy = true  # Ensures that a new stage is created before destroying the old one
    ignore_changes = [deployment_id]
  }

  depends_on = [aws_api_gateway_deployment.api_deployment]
}
