resource "aws_vpc" "ian_lab_vpc" {
  cidr_block = "10.0.0.0/16" # 이 네트워크가 사용할 IP 주소 범위입니다.
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "ian-lab-vpc"
  }
}