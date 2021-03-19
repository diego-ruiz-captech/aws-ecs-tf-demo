output "ec2_private_key_pem" {
  value = tls_private_key.ssh.private_key_pem
}