data "aws_dynamodb_table" "existing_greetings_table" {
  name = var.greetings_table_name
}

resource "aws_dynamodb_table" "greetings" {
  count        = length(data.aws_dynamodb_table.existing_greetings_table.id) == 0 ? 1 : 0
  name         = var.greetings_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(
    var.tags,
    { Name = var.greetings_table_name }
  )

}

# data "aws_dynamodb_table" "existing_terraformlocks_table_ec2_branch" {
#   name = var.terraform_locks_table_name_ec2_branch
# }

resource "aws_dynamodb_table" "terraform_locks_table_ec2_branch" {
  #count = length(try([data.aws_dynamodb_table.existing_terraformlocks_table_ec2_branch.id], [])) == 0 ? 1 : 0
  name         = var.terraform_locks_table_name_ec2_branch
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    var.tags,
    { Name = var.terraform_locks_table_name_ec2_branch }
  )
}

# data "aws_dynamodb_table" "existing_terraformlocks_table_master" {
#   name = var.terraform_locks_table_name_master
# }

resource "aws_dynamodb_table" "terraform_locks_table_master" {
  #count        = length(data.aws_dynamodb_table.existing_terraformlocks_table_master.id) == 0 ? 1 : 0
  name         = var.terraform_locks_table_name_master
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    var.tags,
    { Name = var.terraform_locks_table_name_master }
  )
}