variable "greetings_table_name" {
  description = "The name of the DynamoDB table for storing greetings"
  type        = string
  default     = "greetings_table"
}

variable "terraform_locks_table_name_ec2_branch" {
  description = "The name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform_locks_table_ec2_branch"
}

variable "terraform_locks_table_name_master" {
  description = "The name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform_locks_table_master"
}

variable "tags" {
  description = "Tags to apply to the DynamoDB tables"
  type        = map(string)
  default     = {
    Environment = "Test"
  }
}
