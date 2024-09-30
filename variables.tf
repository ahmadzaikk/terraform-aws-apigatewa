variable "region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to integrate with API Gateway."
  type        = string
}

variable "api_gateway_name" {
  description = "Name for the API Gateway."
  type        = string
}

variable "api_gateway_description" {
  description = "Description for the API Gateway."
  type        = string
  default     = "REST API for Lambda Integration"
}

variable "root_path_part" {
  description = "Path part for the root resource."
  type        = string
  default     = "api"
}

variable "child_resource_path" {
  description = "Path part for the child resource."
  type        = string
  default     = "example"
}

variable "http_method" {
  description = "HTTP Method for the API Gateway resource."
  type        = string
  default     = "GET"
}

variable "authorization" {
  description = "Authorization type for the API Gateway method (NONE, AWS_IAM, COGNITO_USER_POOLS)."
  type        = string
  default     = "NONE"
}

variable "stage_name" {
  description = "Stage name for the API Gateway deployment."
  type        = string
  default     = "dev"
}
