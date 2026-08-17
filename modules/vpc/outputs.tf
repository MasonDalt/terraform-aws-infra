output "vpcid" {
  description = "Its vpc ID"
  value       = aws_vpc.dev.id
}

output "subnetid" {
  description = "Its subnet ID"
  value       = aws_subnet.main.id
}
