# 현재 리전의 가용역역을 문자열형태의 리스트로 반환
data "aws_availability_zones" "available_az" {
    state       = "available"
}