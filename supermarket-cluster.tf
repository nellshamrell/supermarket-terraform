provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "aws_instance" "chef_server" {
  ami = "ami-9abea4fb"
  instance_type = "t2.medium"
  tags {
    Name = "test-chef-server"
  }

  provisioner "local-exec" {
    command = "curl -L https://www.chef.io/chef/install.sh | sudo bash"
  }

  provisioner "local-exec" {
    command = "sudo mkdir -p /var/chef/cache /var/chef/cookbooks"
  }

  provisioner "local-exec" {
    command = "wget -qO- https://supermarket.chef.io/cookbooks/chef-server/download | sudo tar xvzC /var/chef/cookbooks"
  }

  provisioner "local-exec" {
    command = "for i in {1..5}; do echo \"Welcome $i times\" >> something.txt; done"
  }
}
