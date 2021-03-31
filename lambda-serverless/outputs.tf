output "bastion_ip" {
  value = module.ec2-instance.public_ip
}