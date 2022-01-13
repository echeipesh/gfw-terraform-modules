locals {
  tags = merge(
    {
      Name = "${var.project}-${var.compute_environment_name}-batch-job${var.suffix}",
    },
  var.tags)

  launch_template_name = var.use_ephemeral_storage == true ? "${var.project}-ECS-optimized-${var.compute_environment_name}${var.suffix}" : var.use_ephemeral_storage == false ? "${var.project}-ECS-optimized-${var.compute_environment_name}${var.suffix}" : ""

}

resource "aws_launch_template" "ecs-optimized" {

  name = local.launch_template_name

  disable_api_termination = false
  image_id                = data.aws_ami.latest-amazon-ecs-optimized.image_id
  security_group_names    = []
  tags                    = var.tags

  key_name = var.key_pair

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = "true"
      encrypted             = "false"
      snapshot_id           = data.aws_ami.latest-amazon-ecs-optimized.root_snapshot_id
      volume_size           = var.use_ephemeral_storage == true ? 30 : var.ebs_volume_size
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  user_data = var.use_ephemeral_storage == true ? data.local_file.mount_tmp_enable_swap.content_base64 : ""
}


resource "aws_batch_compute_environment" "default" {

  compute_environment_name_prefix = "${var.project}-${var.compute_environment_name}${var.suffix}"

  compute_resources {

    bid_percentage = var.bid_percentage
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    ec2_key_pair   = var.key_pair

    instance_role       = aws_iam_instance_profile.ecs_instance_role.arn
    spot_iam_fleet_role = aws_iam_role.ec2_spot_fleet_role.arn

    instance_type = var.instance_types

    max_vcpus = var.max_vcpus
    min_vcpus = var.min_vcpus

    security_group_ids = var.security_group_ids

    subnets = var.subnets

    launch_template {
      launch_template_id = aws_launch_template.ecs-optimized.id
      version            = aws_launch_template.ecs-optimized.latest_version
    }

    type = var.launch_type
    tags = local.tags
  }

  lifecycle {
    ignore_changes = [
      compute_resources.0.desired_vcpus,
    ]
    create_before_destroy = true
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  state        = "ENABLED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]

}