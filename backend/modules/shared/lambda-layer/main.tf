# Lambda Layer Module - Main

# ============================================================================
# Data Sources & Locals
# ============================================================================

locals {
  # Hash of all files in the source directory to detect changes
  source_files_hash = sha256(join("", [
    for f in fileset(var.source_path, "**") : filesha256("${var.source_path}/${f}")
  ]))

  output_zip_path = "${var.build_path}/layer.zip"
}

# ============================================================================
# Build Trigger (null_resource)
# ============================================================================

resource "null_resource" "build" {
  triggers = {
    source_hash = local.source_files_hash
  }

  provisioner "local-exec" {
    command = "${path.module}/build.sh ${var.source_path} ${var.build_path}"
  }
}

# ============================================================================
# Archive File
# ============================================================================

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.build_path
  output_path = local.output_zip_path

  # Depends on the build finishing
  depends_on = [null_resource.build]
}

# ============================================================================
# Lambda Layer Version
# ============================================================================

resource "aws_lambda_layer_version" "this" {
  layer_name          = "${var.environment}-${var.project_name}-${var.layer_name}"
  description         = var.description
  filename            = data.archive_file.zip.output_path
  source_code_hash    = data.archive_file.zip.output_base64sha256
  compatible_runtimes = var.compatible_runtimes
  license_info        = var.license_info

  tags = var.tags
}
