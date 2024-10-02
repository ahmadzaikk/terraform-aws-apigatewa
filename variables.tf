
# Define variables
variable "region" {
  description = "The AWS region"
  default     = "us-west-2"  # Adjust as needed
}

# variable "lambda_function_arn" {
#   description = "The ARN of the Lambda function"
#   type        = string
# }

# variable "lambda_function_name" {
#   description = "The name of the Lambda function"
#   type        = string
# }

variable "stage_name" {
  description = "The name of the deployment stage"
  type        = string
}

variable "api_resources" {
  description = "Map of API resources, methods, and associated Lambda functions"
  type = map(object({
    path_part           = string
    methods             = list(string)
    lambda_function_arn = string
    lambda_function_name = string
  }))
}

variable "api_stages" {
  type    = list(string)
  default = ["dev", "prod"]
}

variable "allowed_ips" {
  description = "allowed IP"
  type = list (string)
  
}

