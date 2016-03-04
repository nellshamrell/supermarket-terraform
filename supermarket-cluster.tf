provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# Create security group for servers in this cluster

resource "aws_security_group" "allow-ssh" {
  name = "allow-ssh"
  tags {
    Name = "Allow All SSH"
  }
}

resource "aws_security_group_rule" "allow-ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.allow-ssh.id}"
}

resource "aws_security_group_rule" "allow_all_egress" {
    type = "egress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.allow-ssh.id}"
}

# Setup chef-server
resource "aws_instance" "chef_server" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  tags {
    Name = "test-chef-server"
  }
  security_groups = ["${aws_security_group.allow-ssh.name}"]
}
