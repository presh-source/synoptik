# Lambda Layer Module - Main

# ============================================================================
# Data Sources & Locals
# ============================================================================

locals {
  # Hash of all files in the source directory to detect changes
  # Use try() to handle case where directory doesn't exist yet
  source_files = try(fileset(var.source_path, "**"), [])
  source_files_hash = length(local.source_files) > 0 ? sha256(join("", [
    for f in local.source_files : filesha256("${var.source_path}/${f}")
  ])) : sha256("empty")

  output_zip_path = "${var.build_path}/layer.zip"
}

# ============================================================================
# Build Trigger (null_resource)
# ============================================================================

resource "null_resource" "build" {
  triggers = {
    source_hash = local.source_files_hash
    # Force rebuild if build output doesn't exist
    always_build = fileexists("${var.build_path}/python") ? "exists" : timestamp()
  }

  provisioner "local-exec" {
    command = "mkdir -p ${var.build_path} && ${path.module}/build.sh ${var.source_path} ${var.build_path}"
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
}
