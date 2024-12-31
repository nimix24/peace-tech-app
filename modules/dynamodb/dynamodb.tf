data "aws_dynamodb_table" "existing_greetings_table" {
  name = "greetings_table"
}

# DynamoDB Table for storing greetings
resource "aws_dynamodb_table" "greetings" {
  count          = length(data.aws_dynamodb_table.existing_greetings_table.id) > 0 ? 0 : 1
  name           = "greetings_table"
  billing_mode   = "PAY_PER_REQUEST" # Automatically scales based on usage
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S" # String type for the primary key
  }

  tags = {
    Name = "greetings_table"
    Environment = "Test"
  }
}

data "aws_dynamodb_table" "existing_terraformlocks_table" {
  name = "terraformlocks_table"
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  count        = length(data.aws_dynamodb_table.existing_terraformlocks_table.id) > 0 ? 0 : 1
  name         = "terraformlocks_table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraformlocks_table"
    Environment = "Test"
  }
}
