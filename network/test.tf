# resource "aws_instance" "this" {
#     count = 2
#     subnet_id = "subnet-0431fb82b708afdab"
#     ami     = "ami-006f82a1d5a27da54"
#     instance_type   = "t3.nano"
#     tags = {
#         Name ="test${count.index+1}-instance"
#     }
# }

# resource "aws_instance" "this" {
#     for_each = toset(["logs", "media", "backups"])
#     subnet_id = "subnet-0431fb82b708afdab"
#     ami     = "ami-006f82a1d5a27da54"
#     instance_type   = "t3.nano"
#     tags = {
#         Name ="test-${each.key}-instance"
#     }
# }

# resource "aws_instance" "this" {
#     for_each = {
#         "a" = "logs"
#         "b" = "media"
#         "c" = "backups"
#     }
#     subnet_id = "subnet-0431fb82b708afdab"
#     ami     = "ami-006f82a1d5a27da54"
#     instance_type   = "t3.nano"
#     tags = {
#         Name ="test-${each.key}-instance" # each.value
#     }
# }

# output "prt_instance" {
#     value =aws_instance.this["b"].tags
# }