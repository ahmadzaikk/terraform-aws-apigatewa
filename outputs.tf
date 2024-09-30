output "api_gateway_url" {
  description = "The URL of the API Gateway."
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "lambda_function_arn" {
  description = "The ARN of the integrated Lambda function."
  value       = aws_lambda_function.lambda.arn
}
