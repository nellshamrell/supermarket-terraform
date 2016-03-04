provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# Setup chef-server
resource "aws_instance" "chef_server" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  tags {
    Name = "test-chef-server"
  }
  security_groups = ["${var.security_group_names}"]
}
