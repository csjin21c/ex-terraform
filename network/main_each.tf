# terraform init: 테라폼 초기화
# plan: 테라폼을 통해 배포 가능한지 확인(--out=filename 옵션을 통해 plan 파일 생성 가능)
# apply: 테라폼을 통해 배포(--auto-approve 옵션을 통해 자동 승인 가능)
# destroy: 테라폼을 통해 배포된 리소스 삭제(--auto-approve 옵션을 통해 자동 승인 가능)
resource "aws_vpc" "ian_vpc" {
    cidr_block           = var.vpc_cidr
    instance_tenancy     = "default"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags                 = {
        Name = "${local.tag_header}vpc"
    }
}

# ########################################################################
# Public Subnet 생성
# ========================================================================
resource "aws_subnet" "ian_public_subnet" {
    for_each = toset(local.azs)

    vpc_id                  = aws_vpc.ian_vpc.id
    cidr_block              = var.subnet_cidr[0][each.key]
    availability_zone       = each.key

    # Public Subnet 설정에 사용
    # map_public_ip_on_launch = var.subnet_type[0]=="public" ? true : false
    map_public_ip_on_launch = true
    enable_resource_name_dns_a_record_on_launch = true

    tags = {
        Name = "${local.tag_header}public${split("-",each.key)[length(split("-",each.key))-1]}-subnet"
    }
}


# ########################################################################
# Private Subnet 생성
# ========================================================================
resource "aws_subnet" "ian_private_subnet" {
    for_each = toset(local.azs)
    # count                   = length(local.azs)
    vpc_id                  = aws_vpc.ian_vpc.id
    cidr_block              = var.subnet_cidr[1][each.key]
    availability_zone       = each.key

    tags = {
        Name = "${local.tag_header}private${split("-",each.key)[length(split("-",each.key))-1]}-subnet"
    }
}
# ########################################################################
# Gateway 생성
# ========================================================================
# Internet Gateway 생성
resource "aws_internet_gateway" "ian_igw" {
    vpc_id = aws_vpc.ian_vpc.id

    tags = {
        Name = "${local.tag_header}igw"
    }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "ian_nat_eip" {
    domain = "vpc" # VPC용 EIP 생성, ian_nat_eip의 사용범위를 VPC로 제한

    tags = {
        Name = "${local.tag_header}nat-eip"
    }
}

# NAT Gateway 생성
resource "aws_nat_gateway" "ian_nat_gw" {
    allocation_id = aws_eip.ian_nat_eip.id
    # NAT Gateway를 생성할 Public Subnet 지정
    subnet_id     = aws_subnet.ian_public_subnet["ap-south-1a"].id
    # 인터넷 게이트웨이를 먼저 생성(완료)되면 이후 NAT Gateway를 생성하도록 의존성 설정
    depends_on =  [
        aws_internet_gateway.ian_igw
    ]
    tags = {
        Name = "${local.tag_header}nat-gw"
    }
}



# ########################################################################
# Route Table 생성
# ========================================================================
# 1. 생성
resource "aws_route_table" "ian_public_rt" {
    vpc_id = aws_vpc.ian_vpc.id

    tags = {
        Name = "${local.tag_header}public-rt"
    }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "ian_public_rt_assoc" {
      for_each = {
        "ap-south-1a" = aws_subnet.ian_public_subnet["ap-south-1a"].id
        "ap-south-1b" = aws_subnet.ian_public_subnet["ap-south-1b"].id
        "ap-south-1c" = aws_subnet.ian_public_subnet["ap-south-1c"].id
      }
    subnet_id      = each.value
    route_table_id = aws_route_table.ian_public_rt.id
}

# 3. 라우팅
resource "aws_route" "ian_public_rt_route" {
    route_table_id         = aws_route_table.ian_public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.ian_igw.id
}
# Private Route Table 생성 -----------------------------------------------
# Private subnet 1
resource "aws_route_table" "ian_private_rt" {
    for_each = toset(local.azs)

    vpc_id = aws_vpc.ian_vpc.id
    tags = {
        Name = "${local.tag_header}private-${each.key}-rt"
    }
} # aws_route_table.ian_private_rt["ap-south-1a"]

# 2. 서브넷 연결
resource "aws_route_table_association" "ian_private1a_rt_assoc" {
    for_each = toset(local.azs)

    subnet_id      = aws_subnet.ian_private_subnet[each.key].id
    route_table_id = aws_route_table.ian_private_rt[each.key].id
}

# 3. 라우팅
resource "aws_route" "ian_private_rt_route" {
    for_each = toset(local.azs)
    route_table_id         = aws_route_table.ian_private_rt[each.key].id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_nat_gateway.ian_nat_gw.id
}


# ######################################################################
# security group 생성
# ========================================================================
# SSH 접속용 Security Group 생성
resource "aws_security_group" "ian_ssh_sg" {
    name        = "${local.tag_header}ssh-sg"
    description = "Security group for SSH access"
    vpc_id      = aws_vpc.ian_vpc.id

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}ssh-sg"
    }
}

# MySQL 접속용 Security Group 생성
resource "aws_security_group" "ian_mysql_sg" {
    name        = "${local.tag_header}mysql-sg"
    description = "Security group for MySQL access"
    vpc_id      = aws_vpc.ian_vpc.id

    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}mysql-sg"
    }
}
# 웹 보안그룹(ALB용) 생성
resource "aws_security_group" "ian_external_alb_sg" {
    name        = "${local.tag_header}external-alb-sg"
    description = "Security group for web access"
    vpc_id      = aws_vpc.ian_vpc.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}external-alb-sg"
    }
}

# ======== 프라이빗 웹 인스턴스용 보안그룹 ===================================
resource "aws_security_group" "ian_internal_alb_sg" {
    name        = "${local.tag_header}internal-alb-sg"
    description = "Security group for private web access"
    vpc_id      = aws_vpc.ian_vpc.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}internal-alb-sg"
    }
}

# 보안그룹 규칙 추가: 외부 ALB에서 내부 ALB로의 트래픽 허용
resource "aws_security_group_rule" "ian_internal_alb_rule" {
    type                     = "ingress"
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    
    # 소스로 어떤 보안 그룹을 추가할 지 추가할 보안그룹의 아이디 지정
    source_security_group_id = aws_security_group.ian_external_alb_sg.id
    # 규칙을 추가할 보안 그룹의 아이디
    security_group_id        = aws_security_group.ian_internal_alb_sg.id
}

# #############################################################################
# 테라폼은 선언형 언어, IF문이 없다.
# if문을 대체하는 3항 연산자를 통해 간단한 제어만 가능
# [일반 삼항연산자]조건 ? 조건이 참일때의 값 : 조건이 거짓일때의 값
# [다중 삼항연산자]조건1 ? 조건1이 참일때의 값 : (
#                 조건2 ? 조건2가 참일때의 값 : 조건2가 거짓일때의 값)
locals {
    instance_chk = true
}
resource "aws_instance" "csjin_instance" {
  count         = local.instance_chk ? 1 : 0
  ami           = "ami-006f82a1d5a27da54"
  subnet_id     = aws_subnet.ian_public_subnet["ap-south-1a"].id
  instance_type = "t3.micro"

  tags = {
    Name = "csjin-instance-${count.index + 1}"
  }
}


# --------------------------------------------------------------------
# 중첩 삼항 연산자
locals {
    instance_type ="default" # "nano, micor, small"
}

resource "aws_instance" "csjin_ec2" {
    ami             = "ami-006f82a1d5a27da54"
    subnet_id       = aws_subnet.ian_public_subnet["ap-south-1a"].id
    instance_type   = local.instance_type == "default" ? "t3.nano" : (
                      local.instance_type == "micro" ? "t3.micro" : "t3.small")

    tags = {
        Name = "csjin-instance"
    }
}

# ####################################################################
# 문자열 함수
output "zfunc_string_upper" {
    value = upper("abcd") # 대문자로 변환
}

output "zfunc_string_lower" {
    value = lower("aBCd") # 소문자로 변환
}

output "zfunc_string_replace" {
    value = replace("abcdb","bc","K") # 찾은 문자열 모두 치환
}

# 문자열 나누기
# 전체 문자열에서 특정 문자를 기준으로 나누어 리스트로 변환
output "zfunc_string_split" {
    value = split("-", "ap-south-1a")[length(split("-", "ap-south-1a"))-1] # 찾은 문자열 모두 치환
}

# 리스트의 각 요소를 지정 문자를 이용하여 연결
output "zfunc_string_join" {
    value = join("*", split("-","ap-south-a1"))
}

# for 표현식
output "for" {
    value = [for num in [2, 4, 5, 65, 78] : num*num if num%2 == 0]
}

