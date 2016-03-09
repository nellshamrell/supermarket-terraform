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

resource "aws_security_group" "allow-443" {
  name = "allow-443"
  tags {
    Name = "Allow connections over 443"
  }
}

resource "aws_security_group_rule" "allow-443" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.allow-443.id}"
}


resource "aws_security_group_rule" "allow_all_egress" {
    type = "egress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.allow-ssh.id}"
}

# This will create the users and organization
resource "template_file" "chef_bootstrap" {
  template = "${file("chef_bootstrap.tpl")}"

  vars {
    chef-server-user = "${var.chef-server-user}"
    chef-server-user-full-name = "${var.chef-server-user-full-name}"
    chef-server-user-email = "${var.chef-server-user-email}"
    chef-server-user-password = "${var.chef-server-user-password}"
    chef-server-org-name = "${var.chef-server-org-name}"
    chef-server-org-full-name = "${var.chef-server-org-full-name}"
  }
}

# Setup chef-server
resource "aws_instance" "chef_server" {
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  tags {
    Name = "test-chef-server"
  }
  security_groups = ["${aws_security_group.allow-ssh.name}", "${aws_security_group.allow-443.name}"]

  # Uploads all cookbooks needed to install Chef server
  provisioner "file" {
    source = "cookbooks"
    destination = "/tmp" 
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = "${file(\"${var.private_ssh_key_path}\")}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service iptables stop",
      "sudo chkconfig iptables off",
      "curl -LO https://www.chef.io/chef/install.sh && sudo bash ./install.sh -P chefdk -n && rm install.sh",
      "cd /tmp; sudo chef exec chef-client -z -o chef-server",
      "echo '${template_file.chef_bootstrap.rendered}' > /tmp/bootstrap-chef-server.sh",
      "chmod +x /tmp/bootstrap-chef-server.sh",
      "sudo sh /tmp/bootstrap-chef-server.sh",
      "sudo sed -i 's/api_fqdn.*$/api_fqdn \"${self.public_ip}\"/' /etc/opscode/chef-server.rb",
      "sudo chef-server-ctl reconfigure"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = "${file(\"${var.private_ssh_key_path}\")}"
    }
  }
  # Make .chef directory
  provisioner "local-exec" {
    command = "mkdir -p .chef" 
  }
  # This will download the chef user pem to your local workstation
  provisioner "local-exec" {
    command = "scp -oStrictHostKeyChecking=no -i ${var.private_ssh_key_path} ubuntu@${self.public_ip}:${var.chef-server-user}.pem .chef/${var.chef-server-user}.pem"
  }
}

# Template to render knife.rb
resource "template_file" "knife_rb" {
  template = "${file("knife_rb.tpl")}"
  vars {
    chef-server-user = "${var.chef-server-user}"
    chef-server-fqdn = "${aws_instance.chef_server.public_ip}"
    organization = "${var.chef-server-org-name}"
  }
  # Make .chef/knife.rb file
  provisioner "local-exec" {
    command = "echo '${template_file.knife_rb.rendered}' > .chef/knife.rb"
  }
  # Fetch Chef Server Certificate
  provisioner "local-exec" {
    command = "knife ssl fetch"
  }
  # Upload cookbooks to the Chef Server
  provisioner "local-exec" {
    command = "knife cookbook upload --all --cookbook-path cookbooks"
  }
}

# Template for the Supermarket Databag
resource "template_file" "supermarket_databag" {
  template = "${file("supermarket_databag.tpl")}"

  vars {
    chef-server-url = "${aws_instance.chef_server.public_ip}"
  }
}

# Sets up VM for Supermarket
resource "aws_instance" "supermarket_server" {
  depends_on = ["aws_instance.chef_server"]
  ami = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  tags {
    Name = "test-chef-server"
  }
  security_groups = ["${aws_security_group.allow-ssh.name}", "${aws_security_group.allow-443.name}"]


  # Bootstraps Supermarket VM with Chef
  provisioner "local-exec" {
    command = "knife bootstrap ${self.public_ip} -N supermarket-node -x ubuntu --sudo"
  }

  # Make a data bags directory
  provisioner "local-exec" {
    command = "mkdir -p databags/apps"
  }

  # Make json file for supermarket data bag item
  provisioner "local-exec" {
    command = "echo '${template_file.supermarket_databag.rendered}' > databags/apps/supermarket.json"
  }

  # Create the apps data bag on the Chef server
  provisioner "local-exec" {
    command = "knife data bag create apps"
  }

  # Create supermarket data bag item on the Chef server
  provisioner "local-exec" {
    command = "knife data bag from file apps databags/apps/supermarket.json"
  }
}

