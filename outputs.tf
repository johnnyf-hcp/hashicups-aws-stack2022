# Outputs file
output "app_url" {
  value = "http://${aws_instance.hashicups-docker-server.private_dns}"
}

output "app_ip" {
  value = "http://${aws_instance.hashicups-docker-server.private_ip}"
}
