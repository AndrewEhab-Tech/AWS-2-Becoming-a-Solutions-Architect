resource "aws_dynamodb_table" "image_metadata" {
  name         = "${var.project_name}-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ImageId"

  attribute {
    name = "ImageId"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "S"
  }

  # Global Secondary Index (GSI) for querying images by processing status and creation time
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "Status"
    range_key       = "CreatedAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-metadata-table"
  }
}
