# output "api_gateway_url" {
#   description = "The URL of the API Gateway."
#   value       = aws_api_gateway_stage.api_stage.invoke_url
# }

# output "lambda_function_arn" {
#   description = "The ARN of the integrated Lambda function."
#   value       = aws_lambda_function.lambda.arn
# }

# Output the API Gateway URL
# output "api_gateway_url" {
#   value = aws_api_gateway_stage.api_stage.invoke_url
# }

# Output API URL for each stage
output "api_urls" {
  value = { for stage in var.api_stages : stage => "${aws_api_gateway_rest_api.rest_api.execution_arn}/${stage}/example" }
}
