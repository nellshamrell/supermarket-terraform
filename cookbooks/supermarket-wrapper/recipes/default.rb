#
# Cookbook Name:: supermarket-wrapper
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

app = data_bag_item('apps', 'supermarket')
node.set['supermarket_omnibus']['chef_server_url'] = app['chef_server_url']
node.set['supermarket_omnibus']['chef_oauth2_app_id'] = app['uid']
node.set['supermarket_omnibus']['chef_oauth2_secret'] = app['secret']
node.set['supermarket_omnibus']['config']['fqdn'] = app['fqdn']
node.set['supermarket_omnibus']['config']['host'] = app['fqdn']

include_recipe 'supermarket-omnibus-cookbook'
