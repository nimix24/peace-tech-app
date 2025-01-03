output "greetings_table" {
  description = "The ARN of the greetings DynamoDB table"
  #value       = aws_dynamodb_table.greetings.arn
  value = length(aws_dynamodb_table.greetings) > 0 ? aws_dynamodb_table.greetings[0].arn : null
}

output "terraform_locks_table_ec2_branch" {
  description = "The ARN of the Terraform locks DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks_table_ec2_branch
  #value = length(aws_dynamodb_table.terraform_locks_table_ec2_branch) > 0 ? aws_dynamodb_table.terraform_locks_table_ec2_branch[0].arn : null
}

output "terraform_locks_table_master" {
  description = "The ARN of the Terraform locks DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks_table_master
  #value = length(aws_dynamodb_table.terraform_locks_table_master) > 0 ? aws_dynamodb_table.terraform_locks_table_ec2_branch[0].arn : null
}
