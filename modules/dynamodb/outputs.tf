output "greetings_table_arn" {
  description = "The ARN of the greetings DynamoDB table"
  value       = aws_dynamodb_table.greetings[0].arn
}

output "terraform_locks_table_arn" {
  description = "The ARN of the Terraform locks DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks_table[0].arn
}
