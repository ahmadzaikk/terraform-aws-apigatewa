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
# Loop over each resource to create methods
resource "aws_api_gateway_method" "api_method" {
  for_each = var.api_resources

  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.api_resource[each.key].id
  http_method   = each.value.methods[0]  # Using the first method as an example
  authorization = "NONE"                 # Adjust as needed
}

# Integrate the methods with the respective Lambda function for each resource
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

# Create a null resource to force redeployment whenever resource or policy changes occur
locals {
  # Decode the policy to ensure it's treated consistently during JSON encoding
  normalized_policy = jsondecode(aws_api_gateway_rest_api_policy.rest_api_policy.policy)
}

resource "null_resource" "api_redeploy" {
  triggers = {
    # Encode the api_resources variable to ensure that changes to it trigger a redeployment
    api_resources = jsonencode(var.api_resources)
    stage_name    = var.stage_name
    # Normalize and re-encode the policy to avoid inconsistencies
    policy_change = jsonencode(local.normalized_policy)
  }
}

# Deploy the API
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_method_response.api_method_response,
    aws_api_gateway_method_response.options_method_response,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration,
    aws_api_gateway_rest_api_policy.rest_api_policy,
    null_resource.api_redeploy
  ]

  rest_api_id = aws_api_gateway_rest_api.rest_api.id
}

# Create a stage for the deployment
resource "aws_api_gateway_stage" "api_stage" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id

  # Ensures that the stage gets updated whenever the deployment changes
  lifecycle {
    create_before_destroy = true
  }
}

