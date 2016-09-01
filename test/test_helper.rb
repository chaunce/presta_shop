$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'presta_shop'

require 'minitest/autorun'
require 'webmock/minitest'

# No real network connections allowed during testing
WebMock.disable_net_connect!
