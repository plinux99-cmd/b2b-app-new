resource "aws_guardduty_detector" "this" {
  enable = true

  # NOTE: the `datasources` block was deprecated in favor of
  # `aws_guardduty_detector_feature` resources. For now we enable the
  # detector and leave datasource features to be created explicitly using
  # `aws_guardduty_detector_feature` (see AWS provider docs). Example (commented):
  #
  # resource "aws_guardduty_detector_feature" "s3_logs" {
  #   detector_id = aws_guardduty_detector.this.id
  #   name        = "S3_LOGGING"
  #   enable      = true
  # }
}
