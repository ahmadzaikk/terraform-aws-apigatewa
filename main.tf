provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Define the API Gateway
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.name
  description = "API Gateway with Lambda integration (non-proxy) and CORS enabled"
}

# Define API resources
resource "aws_api_gateway_resource" "api_resource" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = each.value.path_part
}

# Define methods for each resource
resource "aws_api_gateway_method" "api_method" {
  for_each = var.api_resources

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = each.value.methods[0]
  authorization = "NONE"
}

# Integrate methods with Lambda functions
resource "aws_api_gateway_integration" "lambda_integration" {
  for_each = var.api_resources

  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.api_resource[each.key].id
  http_method             = aws_api_gateway_method.api_method[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${each.value.lambda_function_arn}/invocations"

  depends_on = [
    aws_api_gateway_method.api_method,
    aws_api_gateway_method_response.api_method_response
  ]
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "allow_api_gateway" {
  for_each = var.api_resources

  statement_id  = "AllowExecutionFromAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.rest_api.id}/*/*"
}

# Method responses for CORS
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

# Integration responses for CORS
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

  depends_on = [
    aws_api_gateway_method_response.api_method_response,
    aws_api_gateway_integration.lambda_integration
  ]
}

# OPTIONS method for CORS
resource "aws_api_gateway_method" "options_method" {
  for_each = var.api_resources

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# MOCK integration for OPTIONS method
resource "aws_api_gateway_integration" "options_integration" {
  for_each = var.api_resources

  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.api_resource[each.key].id
  http_method             = aws_api_gateway_method.options_method[each.key].http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# OPTIONS method response for CORS
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

# Integration response for OPTIONS method
resource "aws_api_gateway_integration_response" "options_integration_response" {
  for_each = var.api_resources

  rest_api_id = aws_api_gateway_integration.options_integration[each.key].rest_api_id
  resource_id = aws_api_gateway_integration.options_integration[each.key].resource_id
  http_method = aws_api_gateway_method.options_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_method_response.options_method_response]
}

# API Gateway resource policy
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

# Force redeployment on every `terraform apply`
resource "null_resource" "api_redeploy_trigger" {
  provisioner "local-exec" {
    command = "echo 'Triggering redeployment of API Gateway'"
  }

  triggers = {
    always_run = timestamp()
  }
}

# Deploy the API
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  depends_on = [
    null_resource.api_redeploy_trigger,
    aws_api_gateway_method_response.api_method_response,
    aws_api_gateway_method_response.options_method_response,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_rest_api_policy.rest_api_policy
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Create a stage for the deployment
resource "aws_api_gateway_stage" "api_stage" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id

  lifecycle {
    create_before_destroy = true
  }
}
