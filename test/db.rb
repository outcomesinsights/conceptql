require 'sequelizer'

DB = Object.new.extend(Sequelizer).db unless defined?(DB)